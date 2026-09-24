# CRIMSON RAILS — s05e09, проверка.
#
# Поток — это не «ответ пришёл». Это список действий над страницей: что
# заменить, куда дописать, что сказать. Поэтому проверяется то, что Turbo с
# ним сделает: поток прикладывается к той самой странице, с которой отправили
# форму, — и спрашивается, что на ней стало. Цель, которой на странице нет,
# Turbo молча пропустит; здесь такая цель — проваленная проверка.

require_relative "../../support/check.rb"

class StreamTest < Crimson::Test
  include ActionView::RecordIdentifier

  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    @ner = road("NER", "Северо-восточная")
    @september = Settlement.create!(company: @mid, period: "1891-09", pence: 192_240)
    @august = Settlement.create!(company: @mid, period: "1891-08", pence: 190_560, state: :paid)
  end

  # Лист расчётов, с которого нажимают «Оплатить», и форма оплаты сентября.
  def open_sheet
    get path(:company_settlements, @mid)
    assert_status 200
    page
  end

  def pay_form(doc, settlement = @september)
    doc.css("form").find { |form| URI(form["action"].to_s).path == payment_path(settlement) } ||
      flunk("У строки расчёта #{settlement.period} нет кнопки «Оплатить», которая шлёт выплату " \
            "на адрес этого расчёта.")
  end

  def payment_path(settlement) = path(:company_settlement_payment, settlement.company, settlement)

  def pay_by_turbo(doc, settlement = @september)
    submit(form: pay_form(doc, settlement), headers: { "Accept" => Crimson::TURBO_ACCEPT })
  end

  # ─── маршрут и кнопка ───────────────────────────────────────────────────

  def test_a_payment_is_routed_to_its_settlement
    assert_equal "payments#create", route(:post, "/companies/MID/settlements/1891-09/payment"),
                 "Выплате некуда уйти: POST …/settlements/1891-09/payment никуда не ведёт."
    assert_nil route(:get, "/companies/MID/settlements/1891-09/payment"),
               "Выплату можно запросить GET-ом. GET ничего не меняет — а выплата меняет всё."
  end

  def test_only_a_pending_settlement_can_be_paid_from_the_sheet
    doc = open_sheet
    pay_form(doc, @september)
    assert_nil doc.css("form").find { |form| URI(form["action"].to_s).path == payment_path(@august) },
               "У оплаченного расчёта есть кнопка «Оплатить». Деньги уже ушли."
  end

  # ─── поток ──────────────────────────────────────────────────────────────

  def test_turbo_gets_a_stream
    pay_by_turbo(open_sheet)
    assert_status 200
    assert_equal Crimson::TURBO_STREAM, media_type,
                 "Turbo попросил поток первым, а получил другое. Ответ потоком — " \
                 "`format.turbo_stream` в `respond_to`."
    assert @september.reload.paid?, "Расчёт не оплачен."
  end

  def test_every_target_of_the_stream_is_on_the_page
    sheet = open_sheet
    pay_by_turbo(sheet)
    refute_empty streams, "В ответе нет ни одного действия потока."
    assert_empty missing_stream_targets(sheet),
                 "Поток целится в то, чего на листе нет: #{missing_stream_targets(sheet).join('; ')}. " \
                 "Turbo такую цель молча пропустит, и кассир увидит, что «ничего не произошло»."
  end

  def test_the_stream_lands_on_the_road_page_too
    get path(:company, @mid)
    road_page = page
    pay_by_turbo(road_page)
    assert_empty missing_stream_targets(road_page),
                 "На странице дороги, где лист вклеен фреймом, цели потока не нашлись: " \
                 "#{missing_stream_targets(road_page).join('; ')}."
  end

  def test_after_the_stream_the_row_says_paid_and_has_no_button
    sheet = open_sheet
    pay_by_turbo(sheet)
    after = apply_streams(sheet)
    row = after.at_css("[id='#{dom_id(@september)}']")
    refute_nil row, "После потока строки сентября на странице нет: её убрали, а не заменили."
    assert_includes row.text, "оплачен", "После потока строка сентября не говорит «оплачен»."
    assert_nil row.at_css("form"), "После потока у оплаченной строки осталась кнопка «Оплатить»."
    assert_equal 2, after.css("tbody tr").size, "После потока строк в таблице стало не две."
  end

  def test_after_the_stream_the_journal_has_the_confirmation
    sheet = open_sheet
    pay_by_turbo(sheet)
    journal = apply_streams(sheet).at_css("[id='#{dom_id(@mid, :payments)}']")
    refute_nil journal, "На листе нет журнала подтверждений с id #{dom_id(@mid, :payments)}."
    assert_includes journal.text, "1891-09", "Подтверждение не дописано в журнал."
    assert_includes journal.text, "£801 0s 0d"
  end

  def test_after_the_stream_it_is_said_aloud
    sheet = open_sheet
    status = sheet.at_css("[role='status'][id]")
    refute_nil status,
               "На листе нет пустой живой области заранее. Читающий вслух услышит то, что в ней " \
               "появится, только если область была на странице до того."
    pay_by_turbo(sheet)
    said = apply_streams(sheet).at_css("[id='#{status['id']}']").text.squish
    assert_includes said, "1891-09", "После оплаты в живой области ничего не сказано."
  end

  def test_the_stream_carries_fragments_not_pages
    pay_by_turbo(open_sheet)
    streams.each do |item|
      next unless item[:template]

      assert_nil item[:template].at_css("html, body, main, nav, h1"),
                 "Поток «#{item[:action]} → #{item[:target]}» несёт целую страницу. В потоке — " \
                 "куски, и каждый встаёт на своё место."
    end
  end

  # ─── без Turbo ──────────────────────────────────────────────────────────

  def test_without_turbo_it_is_303_to_the_sheet
    submit(form: pay_form(open_sheet))
    assert_status 303,
                  "Без Turbo выплата ответила не 303. Кто не просит потока, получает то, что " \
                  "получал бы всегда."
    assert_equal path(:company_settlements, @mid), URI(location).path
    assert @september.reload.paid?
  end

  # ─── устаревшая страница ────────────────────────────────────────────────

  def test_a_stale_page_gets_the_truth_and_a_reason
    stale = open_sheet
    @september.pay!
    pay_by_turbo(stale)
    assert_status 422,
                  "Расчёт уже оплачен, а повторная выплата ответила не 422. Страница, с которой " \
                  "нажали, устарела; выплата случается один раз (s04e09)."
    assert_equal Crimson::TURBO_STREAM, media_type, "Отказ пришёл не потоком: Turbo ничего не покажет."
    after = apply_streams(stale)
    assert_nil after.at_css("[id='#{dom_id(@september)}'] form"),
               "После отказа устаревшая строка по-прежнему предлагает «Оплатить»."
    alert = after.css("[role='alert']").map(&:text).join(" ")
    assert_includes alert, "1891-09", "После отказа не сказано, почему."
    assert_equal 1, Settlement.where(state: :paid, period: "1891-09").count
  end

  def test_a_stale_page_without_turbo_is_422_with_the_reason
    stale = open_sheet
    @september.pay!
    submit(form: pay_form(stale))
    assert_status 422
    assert_includes page.css("[role='alert']").text, "1891-09"
  end

  # ─── в пределах дороги ──────────────────────────────────────────────────

  def test_another_roads_settlement_cannot_be_paid_through_this_road
    # Месяц, который есть только у NER: через адрес MID его не найти.
    theirs = Settlement.create!(company: @ner, period: "1891-07", pence: 480)
    post "/companies/MID/settlements/1891-07/payment"
    assert_status 404,
                  "Расчёт NER за июль оплачен или найден через адрес MID. Расчёт ищут среди " \
                  "расчётов дороги из адреса (s05e06), а не во всём реестре."
    refute theirs.reload.paid?, "Через адрес MID оплачен расчёт NER."
  end
end
