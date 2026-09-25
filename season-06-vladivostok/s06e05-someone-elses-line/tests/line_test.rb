# CRIMSON RAILS — s06e05, проверка: чужая линия.
#
# Чужая система отвечает не только кодом. Она молчит, думает, принимает и
# теряет ответ. Проверяется то, что увидит контора и что увидит линия: сколько
# ждал работник, сколько раз линия передала телеграмму, что стало с книгой,
# пока линия думала. Линия поддельная, но настоящая по сокету: пределы
# ожидания и заголовки — ровно те, что уйдут на станцию.

require_relative "../../support/check.rb"

class LineTest < Crimson::Test
  def setup
    wipe!
  end

  def hand_in(body = "ПАРОХОД ВЫШЕЛ")
    get path(:new_telegram)
    submit({ addressee: "Нагасаки, дом Лэнга", body: body }, scope: :telegram)
    assert_status 303, "Бланк не принят: 303 после приёма — из s06e01."
    Telegram.last
  end

  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def deliveries = line.requests.select { |request| request.verb == "POST" && request.path == "/messages" }

  def live_through(duration, step: 5.minutes)
    (duration / step).to_i.times do
      travel step
      work_off!
    end
  end

  # ─── молчание ───────────────────────────────────────────────────────────

  def test_a_silent_line_does_not_hold_the_worker
    line.stall!(4)
    telegram = hand_in
    elapsed = timed { work_off! }
    assert_operator elapsed, :<, 3.5,
                    "Линия молчала — и работник ждал её #{elapsed.round(1)} с. Работник у телеграфа " \
                    "один: пока он ждёт, не уходит ни одна телеграмма. Ответа ждут не дольше " \
                    "предела — пары секунд, — и дальше это обрыв."
    assert telegram.reload.pending?, "После молчания линии телеграмма должна ждать повтора."
    assert_equal 1, SolidQueue::ScheduledExecution.count,
                 "Молчание линии не повторяется, как обрыв. Станция, которая не ответила за две " \
                 "секунды, может ответить через пять минут."
  end

  def test_a_thinking_line_is_waited_for
    line.stall!(1)
    telegram = hand_in
    work_off!
    assert telegram.reload.sent?,
           "Линия думала секунду — и работник её не дождался. Предел ожидания — чтобы не ждать " \
           "вечно, а не чтобы не ждать вовсе."
  end

  # ─── принято, ответ потерян ──────────────────────────────────────────────

  def test_a_lost_answer_does_not_send_the_telegram_twice
    line.lose_answer!
    telegram = hand_in
    work_off!
    assert telegram.reload.pending?, "Ответ линии потерялся — а телеграмма уже не в очереди."
    live_through(1.hour)
    assert_equal 2, deliveries.size, "Ответ потерялся — работник должен был подать телеграмму ещё раз."
    assert_equal 1, line.accepted.size,
                 "Линия передала телеграмму дважды. Первая подача дошла, потерялся только ответ; " \
                 "повтор линия не узнала. Каждая подача несёт наш номер отправления " \
                 "(`Idempotency-Key`), и с тем же номером линия второй раз не передаёт."
    assert_equal line.accepted.first[:number], telegram.reload.number,
                 "В книге не тот номер: номер телеграммы — тот, что линия дала при первой подаче."
  end

  def test_every_attempt_carries_the_same_key
    line.break!(2)
    telegram = hand_in
    work_off!
    live_through(1.hour)
    keys = deliveries.map(&:key)
    assert_equal 3, keys.size
    assert_equal [telegram.key] * 3, keys,
                 "Попытки одной телеграммы несут разные номера отправления (или никаких): " \
                 "#{keys.inspect}. Номер отправления — телеграммы, а не попытки."
  end

  def test_two_telegrams_two_keys
    first = hand_in("ПЕРВАЯ")
    second = hand_in("ВТОРАЯ")
    work_off!
    assert_equal [first.key, second.key].sort, deliveries.map(&:key).sort,
                 "Две телеграммы ушли под одним номером отправления — линия примет вторую за " \
                 "повтор первой и не передаст."
    assert_equal 2, line.accepted.size
  end

  # ─── пока линия думает ──────────────────────────────────────────────────

  def test_the_book_is_not_locked_while_the_line_thinks
    line.stall!(1.5)
    hand_in
    worker = Thread.new { ActiveRecord::Base.connection_pool.with_connection { work_off! } }
    sleep 0.4
    elapsed = timed do
      ActiveRecord::Base.connection_pool.with_connection do
        Telegram.create!(addressee: "Лондон", body: "ПОКА ЛИНИЯ ДУМАЕТ")
      end
    end
    worker.join
    assert_operator elapsed, :<, 0.8,
                    "Пока линия думала, контора #{elapsed.round(1)} с не могла записать в книгу " \
                    "ни строки. Работник держал базу — транзакцию или блокировку — всё время " \
                    "разговора с линией. Чужую линию ждут без открытой транзакции."
  end

  # ─── справка ─────────────────────────────────────────────────────────────

  def test_the_line_answers_for_its_own_telegrams
    telegram = hand_in
    work_off!
    unless TelegraphLine.respond_to?(:trace)
      flunk "У клиента линии нет `TelegraphLine.trace(number)` — справки о телеграмме по номеру."
    end
    answer = TelegraphLine.trace(telegram.reload.number)
    assert_equal telegram.number, answer&.fetch("number", nil),
                 "Справка о нашей же телеграмме не вернула её номер."
    line.knows!("НГС-7712")
    refute_nil TelegraphLine.trace("НГС-7712"), "Справка о кабельной квитанции из Нагасаки пуста."
  end

  def test_a_number_the_line_does_not_know_is_an_answer
    flunk "У клиента линии нет `TelegraphLine.trace(number)`." unless TelegraphLine.respond_to?(:trace)
    assert_nil TelegraphLine.trace("ИРК-0331"),
               "На номер, которого линия не знает, справка должна вернуть nil. «Не наша» — ответ " \
               "линии, а не её поломка."
  end

  def test_a_broken_or_silent_line_is_a_break_for_the_trace_too
    flunk "У клиента линии нет `TelegraphLine.trace(number)`." unless TelegraphLine.respond_to?(:trace)
    line.break!
    assert_raises(TelegraphLine::Down, "Справка у лежащей линии — не «не знаю», а обрыв") do
      TelegraphLine.trace("НГС-7712")
    end
    line.stall!(4)
    elapsed = timed do
      assert_raises(TelegraphLine::Down, "Справка у молчащей линии — не ответ, а обрыв") do
        TelegraphLine.trace("НГС-7712")
      end
    end
    assert_operator elapsed, :<, 3.5, "Справку ждали #{elapsed.round(1)} с — без предела."
  end
end
