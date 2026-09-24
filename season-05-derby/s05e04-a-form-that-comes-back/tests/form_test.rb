# CRIMSON RAILS — s05e04, проверка.
#
# Форма проверяется так, как ею пользуются: берётся из ответа, заполняется по
# именам полей и отправляется её адресом и её глаголом. Смотрится, что пришло
# в ответ: 303 и куда — если принято; 422 и та же форма со словами отказа —
# если нет. И что легло в реестр: ровно то, что форма вправе прислать.

require_relative "../../support/check.rb"

class FormTest < Crimson::Test
  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    @gnr = road("GNR", "Великая северная")
  end

  def filled(**over)
    { company_id: @mid.id, reference: "B-0992", description: "чай, ящиков 12",
      sent_on: "1891-10-10", pence: 960, weight_lb: 336 }.merge(over)
  end

  def open_form
    get path(:new_consignment)
    assert_status 200, "Пустой бланк не открылся."
  end

  # ─── маршруты и сама форма ──────────────────────────────────────────────

  def test_the_form_and_its_receiver_are_routed
    assert_equal "consignments#new", route(:get, "/consignments/new"),
                 "Пустого бланка нет: GET /consignments/new никуда не ведёт."
    assert_equal "consignments#create", route(:post, "/consignments"),
                 "Форме некуда отправиться: POST /consignments никуда не ведёт."
  end

  def test_the_form_goes_where_its_receiver_is
    open_form
    form = form_on_page
    assert_equal path(:consignments), URI(form["action"].to_s).path,
                 "Форма отправляется не туда, где её принимают."
    assert_equal "post", form["method"].to_s.downcase
  end

  def test_every_field_has_a_label
    open_form
    fields = form_on_page.css("input, select, textarea").reject { |node| %w[hidden submit].include?(node["type"]) }
    refute_empty fields
    fields.each do |node|
      refute_nil node["id"], "У поля #{node['name']} нет id — подписи не к чему привязаться."
      assert page.at_css("label[for='#{node['id']}']"),
             "У поля #{node['name']} нет подписи. Поле без подписи — клетка без заголовка (s02e03)."
    end
  end

  def test_the_road_page_opens_its_own_form
    get path(:company, @gnr)
    link = page.css("main a[href]").find { |node| URI(node["href"]).path == path(:new_consignment) }
    refute_nil link, "Со страницы дороги нельзя открыть бланк."
    get link["href"]
    assert_status 200
    assert_equal @gnr.id.to_s, form_fields["consignment[company_id]"],
                 "Бланк, открытый со страницы GNR, не знает, что отправитель — GNR."
  end

  # ─── принято ────────────────────────────────────────────────────────────

  def test_an_accepted_form_answers_303_to_the_senders_page
    open_form
    submit(filled, scope: :consignment)
    assert_status 303,
                  "Принятая форма ответила не 303. 303 — «сделано, смотри там»: браузер " \
                  "перейдёт туда запросом GET, и «обновить» не внесёт бланк второй раз."
    assert_equal path(:company, @mid), URI(location).path,
                 "После приёма бланка окно ведёт не на страницу дороги-отправителя."
  end

  def test_the_accepted_form_lies_in_the_registry
    open_form
    submit(filled(reference: " b-0992 "), scope: :consignment)
    record = Consignment.find_by(reference: "B-0992")
    refute_nil record, "Бланк не лёг в реестр."
    assert_equal [@mid.id, 960, 336, Date.new(1891, 10, 10)],
                 [record.company_id, record.pence, record.weight_lb, record.sent_on]
  end

  def test_after_the_redirect_the_office_is_told
    open_form
    submit(filled, scope: :consignment)
    follow!
    assert_status 200
    told = page.css("[role='status']").map { |node| node.text.squish }.join(" ")
    assert_includes told, "B-0992",
                    "После перехода не сказано, что бланк B-0992 внесён. Сообщение о сделанном — " \
                    "живая область: его слышат, не ища."
  end

  # ─── не принято ─────────────────────────────────────────────────────────

  def test_an_empty_form_is_422_and_nothing_lies
    open_form
    submit({}, scope: :consignment)
    assert_status 422,
                  "Непринятая форма ответила не 422. Turbo покажет ответ на форму, только если " \
                  "код говорит, что форма не принята; ответ 200 он не отрисует вовсе."
    assert_equal 0, Consignment.count
    form_on_page
  end

  def test_the_refusal_is_in_the_models_own_words
    open_form
    submit(filled(reference: "", pence: 0, company_id: ""), scope: :consignment)
    assert_status 422
    probe = Consignment.new(filled(reference: "", pence: 0, company_id: nil))
    probe.validate
    alert = page.css("[role='alert']").map { |node| node.text.squish }.join(" ")
    probe.errors.full_messages.each do |message|
      assert_includes alert, message,
                      "Отказ не назван словами модели: нет «#{message}». Кассир читает по-русски " \
                      "и ищет, какое поле поправить."
    end
  end

  def test_what_was_entered_comes_back
    open_form
    submit(filled(reference: ""), scope: :consignment)
    assert_status 422
    fields = form_fields
    assert_equal "чай, ящиков 12", fields["consignment[description]"],
                 "Форма вернулась пустой. Всё, что кассир вписал, он будет вписывать заново."
    assert_equal @mid.id.to_s, fields["consignment[company_id]"]
  end

  def test_a_taken_number_is_refused_in_words
    shipment(@gnr, "B-0992")
    open_form
    submit(filled, scope: :consignment)
    assert_status 422
    assert_includes page.css("[role='alert']").text, taken_message
    assert_equal 1, Consignment.count
  end

  def test_the_index_refusal_is_in_words_too
    open_form
    rival = "INSERT INTO consignments (reference, description, sent_on, pence, weight_lb, " \
            "company_id, settled, created_at, updated_at) VALUES ('B-0992', 'из Лондона', " \
            "'1891-10-09', 480, 100, #{@gnr.id}, 0, '1891-10-09', '1891-10-09')"
    with_rival("consignments", "reference", rival) { submit(filled, scope: :consignment) }
    assert_status 422,
                  "Бланк с тем же номером лёг между проверкой и записью, и окно ответило не " \
                  "422. Отказал индекс (s04e04); его отказ обязан дойти до кассира словами, а " \
                  "не страницей 500."
    assert_includes page.css("[role='alert']").text, taken_message
  end

  def test_a_sender_that_does_not_exist_is_refused_in_words
    open_form
    submit(filled(company_id: 999_999), scope: :consignment)
    assert_status 422, "Дороги-отправителя нет, а ответ не 422."
    assert_equal 0, Consignment.count
  end

  # ─── ровно то, что форма вправе прислать ────────────────────────────────

  def test_fields_beyond_the_form_are_thrown_away
    open_form
    submit(filled, scope: :consignment,
           inject: { "consignment[settled]" => "1", "consignment[id]" => "4242" })
    record = Consignment.find_by(reference: "B-0992")
    refute_nil record
    refute record.settled?,
           "Отметку о расчёте поставил тот, кто вносил бланк, — дописав поле в запрос. " \
           "Сильные параметры пропускают только то, что форма вправе прислать."
    refute_equal 4242, record.id
  end

  def test_a_request_without_a_bill_is_400
    post path(:consignments), params: { reference: "B-0992" }
    assert_status 400,
                  "Запрос без бланка — не непринятый бланк, а неправильный запрос: 400. " \
                  "`params[:consignment].permit` на таком запросе падает с 500."
  end

  private

  def taken_message
    probe = Consignment.new
    probe.errors.add(:reference, :taken)
    probe.errors.full_messages.first
  end
end
