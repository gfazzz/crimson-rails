# CRIMSON RAILS — s06e04, проверка: дважды — как один раз.
#
# Контракт сезона в чистом виде. Очередь обещает «хотя бы раз»: записку на
# выплату исполнят и дважды, и после смерти работника посреди работы, и
# двумя работниками разом, и по второй квитанции на ту же поставку.
# Проверяется эффект: сколько выплат легло в книгу казны и сколько телеграмм
# о них ушло казначейству — на любое число исполнений. «Задача поставлена в
# очередь» не засчитывается: каждая проверка исполняет задачи и считает
# строки.

require_relative "../../support/check.rb"

class IdempotencyTest < Crimson::Test
  def setup
    wipe!
    @shipment = delivery("NGS-0512", kopecks: 240_000)
  end

  def receive(line_number = "НГС-7712", route: "cable", shipment: @shipment)
    unless Acceptance.respond_to?(:receive!)
      flunk "У квитанции нет `Acceptance.receive!`: принять квитанцию — значит записать её " \
            "и оставить записку на выплату (DisburseJob)."
    end
    acceptance = Acceptance.receive!(delivery: shipment, route: route, line_number: line_number,
                                     signed_by: "Кувабара", accepted_on: Date.new(1892, 5, 30))
    refute_empty queued(:DisburseJob), "Квитанция принята — записки на выплату (DisburseJob) в очереди нет."
    acceptance
  rescue ActiveRecord::RecordInvalid => error
    flunk "Квитанцию #{route} #{line_number} второй раз не приняли: #{error.message}. Одна и та же " \
          "телеграмма, пришедшая дважды, — не ошибка отправителя, а работа телеграфа: принять её " \
          "значит найти уже записанную. Проверка уникальности в модели видит строку раньше " \
          "индекса и поднимает RecordInvalid — `create_or_find_by!` его не ловит."
  end

  def disbursements = Disbursement.where(delivery: @shipment)
  def notices = Telegram.where(delivery: @shipment, addressee: "Казначейство постройки, Владивосток")

  def assert_paid_once(context)
    assert_equal 1, disbursements.count,
                 "#{context}: в книге казны #{disbursements.count} выплат за одну поставку. " \
                 "Очередь обещает «хотя бы раз» — «ровно раз» обязана обеспечить задача."
    assert_equal 1, notices.count,
                 "#{context}: казначейству ушло #{notices.count} телеграмм о выплате, а выплата одна."
  end

  # ─── одна квитанция ──────────────────────────────────────────────────────

  def test_a_receipt_is_paid
    receive
    work_off!
    assert_equal 1, disbursements.count, "Квитанция принята, работник прошёл — выплаты нет."
    assert_equal 240_000, disbursements.first.kopecks, "Выплачено не по цене поставки."
    assert_equal 1, notices.count, "Казначейству не ушла телеграмма о выплате."
  end

  def test_the_notice_goes_to_the_line_ahead_of_the_rest
    DispatchJob.perform_later(telegram("ОБЫЧНАЯ"))
    receive
    work_off!
    assert_equal "ВЫПЛАЧЕНО", line.accepted.first&.dig(:body).to_s.split.first,
                 "Телеграмма казначейству о выплате ушла не первой. Она — квитанция казне " \
                 "(у неё есть поставка) и идёт вперёд (s06e02)."
  end

  # ─── два исполнения одной записки ────────────────────────────────────────

  def test_the_same_note_twice
    acceptance = receive
    DisburseJob.perform_later(acceptance)
    work_off!
    assert_paid_once("Две записки на одну квитанцию")
    assert_equal 0, failed_jobs.size,
                 "Вторая записка легла в упавшие. Второе исполнение — не ошибка: очередь так " \
                 "работает. Вторая записка должна кончиться ничем, а не исключением."
  end

  def test_the_worker_dies_after_paying
    receive
    crash_after_effect!
    assert_equal 1, disbursements.count, "Работник выплатил и умер — выплаты в книге нет."
    restart!
    work_off!
    assert_paid_once("Работник выплатил, умер, утром записку исполнили снова")
  end

  def test_the_same_telegram_received_twice
    receive("НГС-7712")
    receive("НГС-7712")
    work_off!
    copies = Acceptance.where(route: "cable", line_number: "НГС-7712").count
    assert_equal 1, copies,
                 copies.zero? ? "Квитанция не легла в книгу квитанций." : "Одна и та же телеграмма легла в книгу квитанций дважды."
    assert_paid_once("Одну телеграмму приняли дважды")
  end

  # ─── две квитанции на одну поставку ─────────────────────────────────────

  def test_a_second_receipt_for_the_same_delivery_is_kept_but_not_paid
    receive("НГС-7712", route: "cable")
    receive("ИРК-0331", route: "overland")
    work_off!
    assert_equal 2, Acceptance.where(delivery: @shipment).count,
                 "Вторая квитанция не легла в книгу. Её надо видеть: это документ, и он о чём-то " \
                 "говорит. Не платить по нему — не значит не записать."
    assert_paid_once("Две квитанции разными путями на одну поставку")
    assert_equal 240_000, disbursements.first.kopecks,
                 "Выплачено не по цене поставки: две квитанции не делают поставку вдвое дороже."
    assert_equal "НГС-7712", disbursements.first.acceptance.line_number,
                 "Выплата записана не по первой квитанции."
  end

  def test_the_key_is_the_delivery_not_the_envelope
    other = delivery("NGS-0513")
    receive("НГС-7712")
    receive("НГС-7713", shipment: other)
    work_off!
    assert_equal 1, Disbursement.where(delivery: other).count,
                 "Две разные поставки — две выплаты. Ключ выплаты — поставка: одна квитанция на " \
                 "одну поставку не должна закрывать другую."
    assert_paid_once("Две поставки")
  end

  # ─── два работника разом ─────────────────────────────────────────────────

  # Две квитанции на одну поставку — кабелем и сушей — и два работника берут
  # их записки в одну и ту же секунду. Оба спрашивают книгу «а не выплачено
  # ли уже?» раньше, чем кто-то из них запишет, — и оба слышат «нет». Окно,
  # которого такой вопрос не видит; видит уникальный индекс (s04e04).
  def test_two_workers_at_once
    receive("НГС-7712", route: "cable")
    receive("ИРК-0331", route: "overland")
    two_workers_at_once!(meet_at: "disbursements")
    assert_equal 0, failed_jobs.size,
                 "Второй работник наткнулся на индекс и упал. Индекс сказал «уже выплачено» — " \
                 "это ответ, а не поломка: задача должна его понять и кончиться ничем."
    assert_paid_once("Два работника разом")
  end

  def test_the_book_itself_refuses_a_second_payment
    receive
    work_off!
    acceptance = Acceptance.last
    assert_raises(ActiveRecord::RecordNotUnique,
                  "База приняла вторую выплату за ту же поставку. «Одна выплата на поставку» " \
                  "держится только в коде задачи — и не держится, когда задачу обходят") do
      ActiveRecord::Base.lease_connection.execute(<<~SQL)
        INSERT INTO disbursements (delivery_id, acceptance_id, kopecks, paid_at, created_at, updated_at)
        VALUES (#{@shipment.id}, #{acceptance.id}, 240000, '1892-05-12', '1892-05-12', '1892-05-12')
      SQL
    end
  end

  # ─── либо оба эффекта, либо ни одного ────────────────────────────────────

  def test_a_payment_without_its_notice_does_not_stay
    receive
    Telegram.set_callback(:create, :after, :lights_out)
    Telegram.define_method(:lights_out) { raise IOError, "свет погас" }
    begin
      work_off!
    ensure
      Telegram.skip_callback(:create, :after, :lights_out)
      Telegram.remove_method(:lights_out)
    end
    assert_equal 0, disbursements.count,
                 "Выплата легла в книгу, а телеграмма о ней — нет: свет погас между ними. Казна " \
                 "заплатила и не сообщила; повтор не сообщит, потому что «уже выплачено». Оба " \
                 "эффекта — в одной транзакции."
    SolidQueue::FailedExecution.find_each(&:retry)
    work_off!
    assert_paid_once("Свет погас, записку вернули")
  end
end
