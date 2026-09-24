# CRIMSON RAILS — s05e02, проверка.
#
# Адрес дороги — её код. Проверяется не то, как это написано, а три свойства,
# из которых это складывается: у дороги один адрес, и он по коду; адрес, не
# похожий на код, не доходит ни до какого действия; и модель с таблицей
# маршрутов согласны, что такое код, — любую дорогу, которую можно завести,
# можно и открыть.

require_relative "../../support/check.rb"

class AddressTest < Crimson::Test
  def setup
    wipe!
  end

  # ─── один адрес, и он по коду ───────────────────────────────────────────

  def test_a_road_is_addressed_by_its_code
    mid = road("MID")
    assert_equal "/companies/MID", path(:company, mid),
                 "Адрес дороги — не её код. Телеграф номеров дорог не передаёт; код знают " \
                 "все, кто пишет по проводу. Адрес строит помощник маршрута, а он спрашивает " \
                 "у записи `to_param`."
  end

  def test_the_route_names_what_it_carries
    found = Rails.application.routes.recognize_path("/companies/MID")
    assert_equal "MID", found[:code],
                 "В адресе лежит код, а маршрут зовёт его `:id`. Адрес обещает номер, а " \
                 "несёт другое; `param: :code` говорит правду."
  end

  def test_the_code_opens_that_road
    road("GNR")
    road("MID", "Мидлендская")
    road("NER")
    get "/companies/MID"
    assert_status 200, "По адресу /companies/MID дорога не открылась."
    assert_equal ["MID"], texts("h1"), "По коду MID открылась страница другой дороги."
  end

  def test_the_number_is_no_longer_an_address
    mid = road("MID")
    get "/companies/#{mid.id}"
    assert_status 404,
                  "Дорогу по-прежнему можно открыть по номеру. Тогда у неё два адреса — одна " \
                  "дорога под двумя ключами, ровно то, что сезон 4 выметал из реестра."
  end

  def test_an_unknown_code_is_404
    road("MID")
    get "/companies/ZZZ"
    assert_status 404, "Код похож на код, а дороги нет: это 404, как в прошлой серии."
  end

  # ─── адрес, не похожий на код ───────────────────────────────────────────

  def test_what_is_not_a_code_is_not_a_route
    road("MID")
    %w[mid Mid 12 M M1D MIDLAND M-D].each do |shape|
      assert_nil route(:get, "/companies/#{shape}"),
                 "«#{shape}» — не код дороги, а маршрут на него есть. Ограничение на параметр " \
                 "решает раньше контроллера: адрес, не похожий на код, не доходит ни до " \
                 "какого действия."
      get "/companies/#{shape}"
      assert_status 404
    end
  end

  # ─── модель и маршруты согласны ─────────────────────────────────────────

  def test_every_road_the_model_accepts_can_be_opened
    %w[GW MID LNWR].each do |code|
      record = road(code)
      get path(:company, record)
      assert_status 200,
                    "Дорогу #{code} завели, а открыть нельзя. Модель и таблица маршрутов " \
                    "по-разному понимают, что такое код; образец у них должен быть один."
      assert_equal [code], texts("h1")
    end
  end

  def test_what_the_model_refuses_the_routes_refuse_too
    %w[M M1D LNWRY MIDLAND M-D].each do |shape|
      record = Company.new(code: shape, name: "Проба")
      record.validate
      refute_empty record.errors[:code],
                   "Модель принимает код «#{shape}», а таблица маршрутов его не откроет. " \
                   "Дорогу заведут — и до неё нельзя будет дойти."
      assert_nil route(:get, "/companies/#{shape.upcase}")
    end
  end

  def test_the_model_still_brings_codes_to_one_spelling
    record = Company.new(code: " mid ", name: "Мидлендская")
    assert record.valid?, "Код « mid » перестал приводиться к MID. Приведение стоит до проверки."
    assert_equal "MID", record.code
  end

  # ─── список ведёт по кодам ──────────────────────────────────────────────

  def test_the_list_links_each_road_by_its_code
    %w[NER GNR MID].each { |code| road(code) }
    get "/companies"
    linked = hrefs.grep(%r{\A/companies/[^/]+\z})
    assert_equal %w[/companies/GNR /companies/MID /companies/NER], linked.uniq,
                 "Ссылки на списке ведут не по кодам. Адрес строит помощник маршрута — " \
                 "если он строится строкой, он разойдётся с таблицей ровно здесь."
  end

  def test_the_road_page_still_links_back
    get path(:company, road("MID"))
    assert_includes hrefs, path(:companies)
  end
end
