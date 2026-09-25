# CRIMSON RAILS — s06e06, проверка: квитанция снаружи.
#
# Линия стучится к конторе сама. Проверяется то, что увидят обе стороны:
# код ответа, который получит линия, и то, что легло в книги дома. Подпись
# проверяется подделкой: чужой секрет, старое время, тело, поправленное после
# подписи. Работа — не в запросе: пока работник не прошёл, выплаты нет.

require_relative "../../support/check.rb"

class ReceiptTest < Crimson::Test
  def setup
    wipe!
    @shipment = delivery("NGS-0512")
  end

  def receipt(number: "НГС-7712", route: "cable", reference: "NGS-0512")
    { number: number, route: route, delivery: reference, signed_by: "Кувабара", accepted_on: "1892-06-16" }
  end

  def receipts_path = path(:receipts)

  # ─── подлинность ────────────────────────────────────────────────────────

  def test_a_signed_receipt_is_accepted
    line_posts(receipts_path, receipt)
    assert_status 202,
                  "Линия прислала подписанную квитанцию — и получила не 202. «Принято, работа " \
                  "впереди» — 202 Accepted: квитанция записана, выплата — дело работника."
    assert_equal "application/json", media_type, "Линия — не человек: ответ ей — JSON, а не страница."
    assert_equal 1, Acceptance.where(line_number: "НГС-7712").count, "Квитанция не легла в книгу."
  end

  def test_an_unsigned_receipt_is_refused
    line_posts(receipts_path, receipt, sign: false)
    assert_status 401, "Квитанцию без подписи приняли. Постучаться может кто угодно."
    assert_empty Acceptance.all, "Неподписанная квитанция легла в книгу."
  end

  def test_a_receipt_signed_with_another_secret_is_refused
    line_posts(receipts_path, receipt, secret: "не-наш-секрет")
    assert_status 401, "Квитанцию, подписанную чужим секретом, приняли."
    assert_empty Acceptance.all
  end

  def test_a_body_changed_after_signing_is_refused
    body = receipt.to_json
    stamp = Time.current.to_i.to_s
    signature = OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.line_secret, "#{stamp}.#{body}")
    forged = body.sub("NGS-0512", "NGS-0513")
    delivery("NGS-0513")
    session.post(receipts_path, params: forged,
                 headers: { "CONTENT_TYPE" => "application/json", "X-Line-Timestamp" => stamp,
                            "X-Line-Signature" => signature })
    assert_status 401,
                  "Тело поправили после подписи — и квитанцию приняли. Подпись проверяют над тем " \
                  "телом, что пришло, байт в байт (`request.raw_post`)."
    assert_empty Acceptance.all
  end

  def test_an_old_signature_is_refused
    line_posts(receipts_path, receipt, at: 1.hour.ago)
    assert_status 401,
                  "Приняли квитанцию, подписанную час назад. Перехваченную подписанную квитанцию " \
                  "можно прислать снова через месяц; время подписи — часть подписи, и старое не " \
                  "принимают."
    line_posts(receipts_path, receipt(number: "НГС-7713"), at: 2.minutes.ago)
    assert_status 202, "Квитанцию двухминутной давности отвергли: линия не всегда отвечает мгновенно."
  end

  def test_the_line_has_no_form_token
    ActionController::Base.allow_forgery_protection = true
    begin
      line_posts(receipts_path, receipt)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
    assert_status 202,
                  "С включённой защитой форм (как на проде) линия получила отказ. У линии нет " \
                  "токена нашей формы: её подлинность доказывает подпись, и защиту форм для " \
                  "этого адреса снимают."
  end

  # ─── работа — не в запросе ───────────────────────────────────────────────

  def test_the_answer_does_not_wait_for_the_payment
    line_posts(receipts_path, receipt)
    assert_equal 0, Disbursement.count,
                 "Выплата сделана прямо в ответ на квитанцию. Линия ждёт ответа, пока контора " \
                 "считает; выплату делает работник (s06e04)."
    work_off!
    assert_equal 1, Disbursement.where(delivery: @shipment).count, "Работник прошёл — выплаты нет."
  end

  # ─── та же квитанция дважды ──────────────────────────────────────────────

  def test_the_same_receipt_twice_is_one_receipt
    2.times { line_posts(receipts_path, receipt) }
    assert_status 202,
                  "Вторую присылку той же квитанции линия получила не как «принято». Линия " \
                  "повторяет, если не услышала ответа: для неё повтор — обычное дело."
    assert_equal 1, Acceptance.where(route: "cable", line_number: "НГС-7712").count,
                 "Одна квитанция, присланная дважды, легла в книгу дважды."
    work_off!
    assert_equal 1, Disbursement.where(delivery: @shipment).count
  end

  # ─── чего контора не знает ──────────────────────────────────────────────

  def test_a_receipt_for_an_unknown_delivery
    line_posts(receipts_path, receipt(reference: "NGS-9999"))
    assert_status 422,
                  "Квитанция на поставку, которой нет в книге, — не 422. Линия должна понять, что " \
                  "контора её услышала и не может принять: 500 она примет за поломку, 202 — за " \
                  "принятое."
    assert_equal "application/json", media_type
    assert_empty Acceptance.all
  end

  def test_a_receipt_that_is_not_json
    line_posts(receipts_path, "ПРИНЯТО NGS-0512")
    assert_status 422, "Квитанция не в JSON — это не поломка конторы, а неверный запрос: 422, а не 500."
  end

  def test_a_receipt_with_a_route_the_office_does_not_know
    line_posts(receipts_path, receipt(route: "pigeon"))
    assert_status 422, "Квитанция по пути, которого нет, — не 422."
    assert_empty Acceptance.all
  end

  # ─── что контора обещает ─────────────────────────────────────────────────

  def test_the_office_listens_only_where_it_said
    assert_equal "receipts#create", route(:post, "/receipts")
    assert_nil route(:get, "/receipts"), "Квитанции линия шлёт; читать их отсюда никто не обещал."
    assert_nil route(:get, "/receipts/1")
  end
end
