# CRIMSON RAILS — s05e11, проверка форматов.
#
# Один адрес — несколько видов ответа, по тому, что спрашивающий готов
# принять. Проверяется форма ответа, а не шаблон: JSON разбирается как JSON,
# CSV — как CSV, и числа в них сверяются с реестром. Чего спрашивающий не
# понимает, ему не отдают: 406.

require_relative "../../support/check.rb"
require "csv"

class FormatsTest < Crimson::Test
  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    @gnr = road("GNR", "Великая северная")
    Settlement.create!(company: @mid, period: "1891-09", pence: 192_240)
    Settlement.create!(company: @mid, period: "1891-08", pence: 190_565, state: :paid)
  end

  def json
    JSON.parse(response.body)
  rescue JSON::ParserError
    flunk "Ответ назван JSON, а разобрать его нельзя: #{response.body[0, 120].inspect}"
  end

  # ─── JSON ───────────────────────────────────────────────────────────────

  def test_the_sheet_answers_json_by_extension
    get "/companies/MID/settlements.json"
    assert_status 200, "Лист расчётов не отвечает JSON-ом по адресу с `.json`."
    assert_equal "application/json", media_type
    assert_equal "MID", json["company"]
  end

  def test_the_sheet_answers_json_by_accept
    get "/companies/MID/settlements", headers: { "Accept" => "application/json" }
    assert_status 200
    assert_equal "application/json", media_type,
                 "Аппарат попросил JSON заголовком `Accept` — и получил страницу. Что он готов " \
                 "принять, спрашивающий говорит сам; адрес для этого менять не обязан."
  end

  def test_the_json_carries_pence_as_whole_numbers
    get "/companies/MID/settlements.json"
    rows = json["settlements"]
    refute_nil rows, "В ответе нет списка `settlements`."
    assert_equal %w[1891-08 1891-09], rows.map { |row| row["period"] }, "Месяцы не по порядку."
    assert_equal [190_565, 192_240], rows.map { |row| row["pence"] },
                 "Пенсы в JSON — не целые числа реестра. Машине нужно число, а не «£801 0s 0d»; " \
                 "деньги целыми пенсами (s04e02) — и в ответе тоже."
    assert_equal %w[paid pending], rows.map { |row| row["state"] }
  end

  def test_the_json_reading_agrees_with_the_page
    get "/companies/MID/settlements.json"
    helper = Object.new.extend(ApplicationHelper)
    rows = json["settlements"] || flunk("В JSON листа нет списка `settlements`.")
    rows.each do |row|
      assert_equal helper.money(row["pence"]), row["reading"],
                   "Чтение в JSON не совпадает с чтением на странице."
    end
  end

  def test_the_registry_answers_json_with_full_addresses
    get "/companies.json"
    assert_status 200
    rows = json
    assert_equal %w[GNR MID], rows.map { |row| row["code"] }
    rows.each do |row|
      address = URI(row["settlements_url"].to_s)
      assert address.host, "Адрес листа в JSON без хоста: аппарат не знает, откуда пришёл ответ."
      get address.path
      assert_status 200, "Адрес листа из JSON никуда не ведёт: #{address.path}."
      assert_equal row["code"], json["company"]
    end
  end

  def test_a_missing_road_is_404_in_json_too
    get "/companies/ZZZ/settlements.json"
    assert_status 404, "Дороги нет — и JSON-ом тоже 404, а не пустой список."
    assert_equal "application/json", media_type,
                 "На 404 аппарат получил страницу, а не JSON: разбирать ему нечего."
    assert json["error"], "В JSON-ответе на 404 не сказано, что случилось."
  end

  # ─── CSV ────────────────────────────────────────────────────────────────

  def test_the_sheet_answers_csv_as_a_file
    get "/companies/MID/settlements.csv"
    assert_status 200
    assert_equal "text/csv", media_type
    disposition = response.headers["Content-Disposition"].to_s
    assert_match(/attachment/, disposition, "CSV отдаётся страницей, а не файлом для сохранения.")
    assert_match(/MID/, disposition, "Имя файла не называет дорогу: у кассы будет десять «settlements.csv».")
  end

  def test_the_csv_is_the_same_sheet
    get "/companies/MID/settlements.csv"
    assert_equal "text/csv", media_type, "Лист по адресу с `.csv` пришёл не CSV-ом."
    table = CSV.parse(response.body, headers: true)
    assert_equal %w[period pence], table.headers.first(2),
                 "Первые столбцы CSV — не месяц и пенсы."
    assert_equal [["1891-08", 190_565], ["1891-09", 192_240]],
                 table.map { |row| [row["period"], Integer(row["pence"], exception: false)] },
                 "В CSV не те строки или пенсы не целые."
  end

  def test_the_csv_link_is_not_taken_by_turbo
    get path(:company_settlements, @mid)
    link = raw_page.css("a[href]").find { |node| URI(node["href"]).path.end_with?(".csv") }
    refute_nil link, "С листа расчётов нет ссылки на CSV для кассы."
    refute_nil(link["download"] || (link["data-turbo"] == "false" ? true : nil),
               "Ссылку на CSV перехватит Turbo: запросит файл и попытается нарисовать его " \
               "страницей. Файл объявляют файлом — `download` — или уводят мимо Turbo.")
  end

  # ─── чего не понимают, того не отдают ───────────────────────────────────

  def test_an_unknown_format_is_406
    get "/companies/MID/settlements.xml"
    assert_status 406,
                  "Лист отдал ответ в формате, которого не умеет. 406 — «в таком виде не отвечу»; " \
                  "страница или пустое тело под видом XML — неправда."
    get "/companies.csv"
    assert_status 406, "Реестр дорог CSV-ом не обещан — а ответил."
  end

  def test_the_page_is_still_a_page
    get path(:company_settlements, @mid)
    assert_status 200
    assert_equal "text/html", media_type
  end
end
