# CRIMSON RAILS — s06e01, проверка: задача — это записка.
#
# Запрос конторы не ждёт линию: он записывает телеграмму и оставляет записку
# работнику. Проверяется, что работу делает именно работник и делает её по
# записке: линия до работника не слышит ничего, после — ровно то, что лежит в
# книге к его приходу. «Задача поставлена в очередь» сама по себе не
# засчитывается: проверка всякий раз зовёт работника и смотрит на линию.

require_relative "../../support/check.rb"

class DispatchTest < Crimson::Test
  def setup
    wipe!
  end

  # Отдать телеграмму так, как её отдаёт контора: бланком со страницы.
  def hand_in(addressee: "Лондон, Сеймур-стрит", body: "ПРИНЯТО NGS-0512 ЧЕТЫРЕ ТЫСЯЧИ ШПАЛ")
    get path(:new_telegram)
    assert_status 200, "Пустого бланка телеграммы нет."
    submit({ addressee: addressee, body: body }, scope: :telegram)
  end

  def dispatch_jobs = queued(:DispatchJob)

  def last_telegram
    Telegram.last || flunk("Телеграмма не записана в книгу: бланк отправлен, а в книге пусто.")
  end

  def the_note
    dispatch_jobs.first || flunk("Записки работнику нет: телеграмма принята, а в очереди пусто.")
  end

  def state_on_page(telegram)
    get path(:telegram, telegram)
    assert_status 200
    page.at_css("main [data-state]")&.then { |node| [node["data-state"], node.text.squish] } ||
      flunk("На странице телеграммы не видно состояния: ни «в очереди», ни номера линии.")
  end

  # ─── запрос не ждёт линию ────────────────────────────────────────────────

  def test_the_office_gets_its_answer_before_the_line_hears_anything
    hand_in
    assert_status 303, "Приём телеграммы отвечает не перенаправлением 303."
    telegram = last_telegram
    assert_equal path(:telegram, telegram), URI(location).path,
                 "После приёма контора должна попасть на страницу этой телеграммы."
    assert_empty line.requests,
                 "Линия услышала телеграмму прямо во время запроса. Контора стоит у аппарата, " \
                 "пока линия думает: запрос отдаёт работу работнику, а не делает её сам."
    assert telegram.pending?, "До работника телеграмма должна быть в очереди, а не «отправлена»."
  end

  def test_a_broken_line_does_not_break_the_office
    line.break!(5)
    hand_in
    assert_status 303,
                  "Линия лежит — и контора получила ошибку. Запрос не должен знать о линии " \
                  "вовсе: её состояние — забота работника."
    assert_equal 1, dispatch_jobs.size, "Записки работнику нет."
  end

  def test_an_empty_form_comes_back_and_leaves_no_note
    hand_in(body: "")
    assert_status 422, "Бланк без текста должен вернуться с 422 (s05e04)."
    assert_empty dispatch_jobs, "На бланк, который не принят, записка работнику уже оставлена."
    assert_empty Telegram.all
  end

  # ─── работу делает работник ──────────────────────────────────────────────

  def test_the_worker_hands_the_telegram_to_the_line
    hand_in(addressee: "Нагасаки, дом Лэнга", body: "ПАРОХОД ВЫШЕЛ")
    assert_equal 1, work_off!, "Работнику нечего делать: записки в очереди нет."
    assert_equal 1, line.accepted.size, "Работник прошёл — линия ничего не приняла."
    assert_equal "Нагасаки, дом Лэнга", line.accepted.first[:to]
    assert_equal "ПАРОХОД ВЫШЕЛ", line.accepted.first[:body]
  end

  def test_the_book_keeps_the_number_the_line_gave
    hand_in
    telegram = last_telegram
    work_off!
    assert_equal 1, line.accepted.size, "Работник прошёл — линия ничего не приняла."
    telegram.reload
    assert telegram.sent?, "Линия приняла телеграмму, а в книге она всё ещё не отправлена."
    assert_equal line.accepted.first[:number], telegram.number,
                 "В книге не тот номер: номер телеграммы даёт линия, приняв её."
    refute_nil telegram.sent_at
  end

  def test_the_page_says_what_became_of_the_telegram
    hand_in
    telegram = last_telegram
    before, = state_on_page(telegram)
    assert_equal "pending", before, "До работника страница должна говорить «в очереди»."
    work_off!
    after, text = state_on_page(telegram)
    assert_equal "sent", after, "Работник прошёл, а страница всё ещё говорит «в очереди»."
    assert_includes text, telegram.reload.number, "На странице нет номера, под которым линия приняла телеграмму."
  end

  def test_each_telegram_gets_its_own_note
    %w[ПЕРВАЯ ВТОРАЯ ТРЕТЬЯ].each { |body| hand_in(body: body) }
    assert_equal 3, dispatch_jobs.size, "Три телеграммы — три записки."
    work_off!
    assert_equal %w[ПЕРВАЯ ВТОРАЯ ТРЕТЬЯ].sort, line.accepted.map { |item| item[:body] }.sort,
                 "Работник прошёл по трём запискам — линия приняла не те три телеграммы."
    Telegram.find_each do |telegram|
      accepted = line.accepted.find { |item| item[:number] == telegram.number }
      assert_equal telegram.body, accepted&.dig(:body),
                   "Номер линии записан не к той телеграмме."
    end
  end

  # ─── записка — ссылка, а не копия ────────────────────────────────────────

  def test_the_note_carries_a_reference_not_a_copy
    hand_in
    telegram = last_telegram
    arguments = arguments_of(the_note)
    assert_equal [{ "_aj_globalid" => telegram.to_global_id.to_s }], arguments,
                 "В записке не ссылка на телеграмму. Работнику передают саму запись — " \
                 "`perform_later(telegram)`, — и Active Job кладёт в очередь её адрес " \
                 "(GlobalID). Копия полей устареет к его приходу. Сейчас в записке: " \
                 "#{arguments.inspect[0, 200]}"
  end

  def test_the_worker_reads_the_telegram_as_it_is_when_he_comes
    hand_in(body: "ПРИНЯТО 4000")
    the_note
    last_telegram.update!(body: "ПРИНЯТО 3950 ПЯТЬДЕСЯТ ГНИЛЫХ")
    work_off!
    assert_equal ["ПРИНЯТО 3950 ПЯТЬДЕСЯТ ГНИЛЫХ"], line.accepted.map { |item| item[:body] },
                 "На линию ушёл старый текст. Поправку внесли в книгу, пока записка лежала, — " \
                 "работник должен взять телеграмму из книги, а не из записки."
  end

  def test_a_withdrawn_telegram_is_not_sent_and_is_not_an_error
    hand_in
    the_note
    last_telegram.destroy!
    work_off!
    assert_empty line.accepted, "Отозванная телеграмма ушла на линию."
    assert_equal 0, failed_jobs.size,
                 "Отозванная телеграмма легла в упавшие задачи. Отдавать нечего — это исход, " \
                 "а не ошибка: такую записку выбрасывают (`discard_on`)."
  end

  def test_a_second_note_for_the_same_telegram_sends_nothing
    hand_in
    telegram = last_telegram
    DispatchJob.perform_later(telegram)
    work_off!
    refute_empty line.accepted, "Работник прошёл — линия ничего не приняла."
    assert_equal 1, line.accepted.size,
                 "Две записки на одну телеграмму — и линия передала её дважды. Ушедшую " \
                 "телеграмму работник второй раз не отдаёт."
  end

  # ─── что контора обещает ─────────────────────────────────────────────────

  def test_the_office_promises_only_what_it_can
    assert_equal "telegrams#index", route(:get, "/telegrams")
    assert_equal "telegrams#new", route(:get, "/telegrams/new")
    assert_equal "telegrams#create", route(:post, "/telegrams")
    assert_equal "telegrams#show", route(:get, "/telegrams/1")
    assert_nil route(:get, "/telegrams/1/edit"),
               "Отданную телеграмму не правят: у линии её уже нет в наших руках. Правки нет — " \
               "и маршрута нет."
    assert_nil route(:delete, "/telegrams/1")
  end

  def test_the_list_shows_every_telegram_with_its_state
    hand_in(body: "ПЕРВАЯ")
    hand_in(body: "ВТОРАЯ")
    work_off!
    hand_in(body: "ТРЕТЬЯ")
    get path(:telegrams)
    assert_status 200
    states = page.css("main [data-state]").map { |node| node["data-state"] }
    assert_equal %w[pending sent sent], states,
                 "В списке не у каждой телеграммы видно состояние, или порядок не «свежие сверху»."
  end
end
