# CRIMSON RAILS — s06e03, проверка: когда рвётся линия.
#
# У неудачи три вида, и у каждого своя судьба. Линия лежит — повторить,
# выждав, и ждать с каждым разом дольше. Линия отказала — не повторять и
# сказать конторе. Сломалось что-то своё — не прятать: положить в упавшие.
# Проверяется, что делает линия и что видит контора, а не то, что написано в
# `retry_on`: проверка ломает линию, передвигает часы и зовёт работника.

require_relative "../../support/check.rb"

class RetryTest < Crimson::Test
  def setup
    wipe!
  end

  def hand_in(body = "ПАРОХОД ВЫШЕЛ", addressee: "Нагасаки, дом Лэнга")
    get path(:new_telegram)
    submit({ addressee: addressee, body: body }, scope: :telegram)
    assert_status 303, "Бланк не принят: 303 после приёма — из s06e01."
    Telegram.last
  end

  def attempts_on_the_line = line.requests.count { |request| request.path == "/messages" }

  # Прожить час, заходя к работнику каждые пять минут: так ведёт себя
  # диспетчер, который раз в секунду смотрит, не наступило ли время.
  def live_through(duration, step: 5.minutes)
    (duration / step).to_i.times do
      travel step
      work_off!
    end
  end

  def the_retry
    SolidQueue::ScheduledExecution.includes(:job).where(job: { class_name: "DispatchJob" }).first ||
      flunk("Повтора нет: после неудачи записка не отложена на потом.")
  end

  # ─── линия лежит ─────────────────────────────────────────────────────────

  def test_a_broken_line_is_tried_again_later
    line.break!(2)
    telegram = hand_in
    work_off!
    assert_equal 1, attempts_on_the_line, "Работник должен был сходить на линию один раз."
    assert telegram.reload.pending?,
               "Линия лежит — и телеграмма уже не в очереди. Лежащая линия поднимется: " \
               "телеграмму надо повторить, а не списать."
    live_through(1.hour)
    assert_equal 1, line.accepted.size, "Линия поднялась, а телеграмма так и не ушла."
    assert telegram.reload.sent?
    assert_equal 3, attempts_on_the_line, "Две неудачи и одна удача — три похода на линию."
  end

  def test_the_worker_does_not_hammer_a_broken_line
    line.break!(1)
    hand_in
    work_off!
    work_off!
    assert_equal 1, attempts_on_the_line,
                 "Работник пошёл на лежащую линию снова тут же. Повтор без паузы — это сто " \
                 "запросов в секунду к станции, которая и так лежит."
    assert_operator the_retry.scheduled_at, :>, Time.current, "Повтор не отложен на потом."
  end

  def test_each_pause_is_longer_than_the_one_before
    line.break!(3)
    hand_in
    pauses = []
    3.times do
      work_off!
      at = the_retry.scheduled_at
      pauses << (at - Time.current)
      travel_to at + 1
    end
    # Полтора раза — с запасом на разброс (`jitter`): его Active Job добавляет к
    # паузе, чтобы сто упавших записок не пришли на линию в одну секунду.
    assert pauses.each_cons(2).all? { |a, b| b > a * 1.5 },
           "Паузы между попытками не растут: #{pauses.map { |p| p.round(1) }.inspect} секунд. " \
           "Линия, которая не поднялась за минуту, вряд ли поднимется через минуту: ждут " \
           "с каждым разом дольше."
  end

  def test_the_book_counts_attempts
    line.break!(2)
    telegram = hand_in
    work_off!
    live_through(1.hour)
    assert_equal attempts_on_the_line, telegram.reload.attempts,
                 "В книге не столько попыток, сколько раз работник ходил на линию."
  end

  def test_the_worker_gives_up_and_says_so
    line.break!(50)
    telegram = hand_in
    work_off!
    live_through(1.day, step: 30.minutes)
    tries = attempts_on_the_line
    assert_operator tries, :<=, 10,
                    "За сутки работник сходил на лежащую линию #{tries} раз. Попытки не " \
                    "бесконечны: после нескольких нужен человек, а не следующая попытка."
    assert telegram.reload.failed?,
           "Работник бросил попытки, а телеграмма в книге всё ещё «в очереди». Контора " \
           "будет ждать то, что уже не уйдёт."
    refute_empty telegram.error.to_s, "На брошенной телеграмме не записано, почему."
    get path(:telegram, telegram)
    assert_equal "failed", page.at_css("main [data-state]")&.[]("data-state"),
                 "Страница брошенной телеграммы не говорит, что она не ушла."
  end

  def test_no_connection_is_a_broken_line_too
    telegram = hand_in
    real = Rails.configuration.x.telegraph_line
    closed = TCPServer.new("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }
    Rails.configuration.x.telegraph_line = "http://127.0.0.1:#{closed}"
    begin
      work_off!
    ensure
      Rails.configuration.x.telegraph_line = real
    end
    assert_equal 0, failed_jobs.size,
                 "Станция не открыла соединение — и записка легла в упавшие. Нет соединения — " \
                 "та же лежащая линия: пройдёт, и повторять стоит."
    assert telegram.reload.pending?, "Нет соединения — а телеграмма уже не в очереди."
    live_through(1.hour)
    assert telegram.reload.sent?, "Станция снова на месте, а телеграмма так и не ушла."
  end

  # ─── линия отказала ──────────────────────────────────────────────────────

  def test_a_refusal_is_not_repeated
    line.reject!(10)
    telegram = hand_in(addressee: "Порт-Артур")
    work_off!
    live_through(1.day, step: 1.hour)
    assert_equal 1, attempts_on_the_line,
                 "Линия отказала — а работник пошёл снова. Отказ не пройдёт, сколько ни " \
                 "повторяй: адресата нет и через час."
    assert telegram.reload.failed?, "Отказ линии не записан на телеграмме."
    assert_includes telegram.error.to_s, "no_such_addressee",
                    "На телеграмме не записана причина, которую назвала линия."
  end

  def test_a_refusal_is_not_a_breakdown
    line.reject!
    hand_in
    work_off!
    assert_equal 0, failed_jobs.size,
                 "Отказ линии лёг в упавшие задачи. Отказ — исход: он записан на телеграмме, " \
                 "и чинить в очереди нечего."
  end

  # ─── своя поломка ────────────────────────────────────────────────────────

  def test_an_answer_the_office_does_not_understand_is_not_hidden
    line.garble!(20)
    hand_in
    work_off!
    live_through(1.hour)
    assert_equal 1, failed_jobs.size,
                 "Линия ответила так, как контора не ждёт (201 без номера), — и это не легло в " \
                 "упавшие задачи. Такое не пройдёт само и не отказ линии: это то, что надо " \
                 "разобрать руками. Проглоченное (`rescue`) или повторяемое (`retry_on " \
                 "StandardError`) — не разберёт никто."
    assert_equal 1, attempts_on_the_line,
                 "Непонятный ответ повторяют, как лежащую линию. Повтор его не поймёт: " \
                 "`retry_on` — для того, что пройдёт само."
  end

  def test_a_retry_stays_in_the_telegraph_queue
    line.break!(1)
    hand_in
    work_off!
    assert_equal "telegraph", the_retry.job.queue_name,
                 "Повтор ушёл из очереди телеграфа — его возьмёт чужой работник."
  end
end
