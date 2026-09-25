# CRIMSON RAILS — s06e08, проверка: страница, которая у тебя уже есть.
#
# HTTP-кеш — копия у читающего. Проверяется протокол: у ответа есть версия;
# тот, кто пришёл с версией, которая ещё верна, получает 304 и пустое тело —
# и контора ради него не читает лист целиком; стоит листу измениться —
# добавили, убрали, поправили — версия другая, и читающий получает лист.

require_relative "../../support/check.rb"

class ConditionalTest < Crimson::Test
  def setup
    wipe!
    @a = delivery("NGS-0512")
    @b = delivery("NGS-0513")
    @first = pay(@a, "НГС-7712")
    @second = pay(@b, "НГС-7713")
  end

  def pay(shipment, number, at: Time.current)
    receipt = Acceptance.create!(delivery: shipment, line_number: number, route: "cable",
                                 signed_by: "Кувабара", accepted_on: Date.new(1892, 5, 10))
    Disbursement.create!(delivery: shipment, acceptance: receipt, kopecks: shipment.kopecks, paid_at: at)
  end

  def sheet(month = "1892-05", format: nil, headers: {})
    get path(:payout, month) + (format ? ".#{format}" : ""), headers: headers
  end

  def etag
    response.headers["ETag"] || flunk("У листа выплат нет версии: ответ пришёл без заголовка ETag.")
  end

  def again_with(tag, month = "1892-05", format: nil) = sheet(month, format: format, headers: { "If-None-Match" => tag })

  # ─── у листа есть версия ────────────────────────────────────────────────

  def test_the_sheet_carries_its_version
    sheet
    assert_status 200
    refute_empty etag
    refute_nil response.headers["Last-Modified"], "У листа нет времени последней правки (Last-Modified)."
    assert_equal 2, page.css("main tbody tr").size, "На листе не две выплаты."
  end

  def test_the_reader_must_ask_every_time
    sheet
    control = response.headers["Cache-Control"].to_s
    assert(control.include?("no-cache") || control.match?(/max-age=0\b/),
           "Лист можно хранить у себя, не спрашивая (Cache-Control: #{control.inspect}). Тогда " \
           "казначейство прочтёт устаревший лист и не узнает об этом: копию у читающего проверяют " \
           "каждый раз — спросом с версией.")
  end

  # ─── лист у тебя уже есть ───────────────────────────────────────────────

  def test_the_same_version_gets_304_and_nothing_else
    sheet
    tag = etag
    rows = queries("disbursements") { again_with(tag) }
    assert_status 304,
                  "Читающий пришёл с версией, которая ещё верна, — и получил лист целиком. «У тебя " \
                  "уже есть» — 304."
    assert_empty response.body.to_s, "Ответ 304 пришёл с телом: лист передан ещё раз."
    loaded = rows.grep(/SELECT "disbursements"\.\*/)
    assert_empty loaded,
                 "Ради ответа 304 контора прочла выплаты целиком. Спросить версию — дёшево " \
                 "(COUNT и MAX); читать строки, чтобы сказать «не изменилось», — нет."
  end

  def test_the_time_of_the_last_change_works_too
    sheet
    since = response.headers["Last-Modified"]
    sheet(headers: { "If-Modified-Since" => since })
    assert_status 304, "Читающий спросил «изменилось ли с такого-то времени» — и получил лист целиком."
  end

  def test_a_later_change_is_seen_by_the_time_too
    sheet
    since = response.headers["Last-Modified"]
    travel 1.hour
    pay(delivery("NGS-0514"), "НГС-7714")
    sheet(headers: { "If-Modified-Since" => since })
    assert_status 200,
                  "Выплата легла после того времени, о котором спросили, — а ответ «не изменилось». " \
                  "Last-Modified — время последней правки листа, а не начало месяца."
  end

  def test_the_telegraph_gets_304_too
    sheet(format: :json)
    assert_status 200
    assert_equal "application/json", media_type
    assert_equal 2, JSON.parse(response.body)["payouts"]&.size, "В JSON листа не две выплаты."
    again_with(etag, format: :json)
    assert_status 304, "Аппарат казначейства пришёл с верной версией — и получил JSON целиком."
  end

  def test_an_empty_month_has_a_version_too
    sheet("1892-07")
    assert_status 200
    again_with(etag, "1892-07")
    assert_status 304, "Пустой лист — тоже лист: у него есть версия, и его не передают заново."
  end

  # ─── лист изменился ─────────────────────────────────────────────────────

  def test_a_new_payout_is_a_new_version
    sheet
    tag = etag
    pay(delivery("NGS-0514"), "НГС-7714")
    again_with(tag)
    assert_status 200, "Выплат стало три, а читающему ответили «у тебя уже есть»."
    refute_equal tag, etag
    assert_equal 3, page.css("main tbody tr").size
  end

  def test_a_removed_payout_is_a_new_version
    sheet
    tag = etag
    @first.destroy!
    again_with(tag)
    assert_status 200,
                  "Выплату убрали из листа, а читающему ответили «у тебя уже есть». Время последней " \
                  "правки от удаления не меняется; версия листа должна знать и число строк."
  end

  def test_an_edited_payout_is_a_new_version
    sheet
    tag = etag
    travel 1.hour
    @second.update!(kopecks: 180_000)
    again_with(tag)
    assert_status 200, "Выплату поправили, а читающему ответили «у тебя уже есть»."
    assert_includes page.at_css("main tbody").text, "1 800 руб. 00 коп."
  end

  def test_each_month_has_its_own_version
    sheet("1892-05")
    may = etag
    pay(delivery("NGS-0601"), "НГС-7801", at: Time.zone.local(1892, 6, 3, 10))
    again_with(may, "1892-06")
    assert_status 200, "Июньский лист ответил «у тебя уже есть» тому, у кого майский."
  end
end
