# CRIMSON RAILS — s06e02, проверка: очередь, которая переживает ночь.
#
# Записка — строка в таблице, и поэтому она переживает всё, что не переживает
# память процесса: ночь, перезапуск, умершего работника. Проверяется, что
# записки ложатся туда, где их возьмут, в том порядке, в каком их надо
# взять, и не раньше, чем их можно исполнить. Поставить в очередь мало:
# всякий раз проверка зовёт работника — того, который слушает эту очередь, —
# и смотрит, что услышала линия и когда.

require_relative "../../support/check.rb"
require "erb"
require "yaml"

class QueueTest < Crimson::Test
  def setup
    wipe!
  end

  def hand_in(body = "ПАРОХОД ВЫШЕЛ")
    get path(:new_telegram)
    submit({ addressee: "Нагасаки, дом Лэнга", body: body }, scope: :telegram)
    assert_status 303, "Бланк не принят: 303 после приёма — из s06e01."
  end

  def at(day, hour, minute = 0) = Time.zone.local(1892, 5, day, hour, minute)

  # Работники из config/queue.yml — так, как их прочтёт `bin/jobs` на
  # продакшене.
  def workers
    file = File.join(Crimson.app, "config/queue.yml")
    config = YAML.safe_load(ERB.new(File.read(file)).result, aliases: true)
    Array(config.dig("production", "workers")).map do |worker|
      { queues: Array(worker["queues"]).flat_map { |item| item.to_s.split(",").map(&:strip) },
        threads: Integer(worker.fetch("threads", 3)), processes: Integer(worker.fetch("processes", 1)) }
    end
  end

  def listening(queue) = workers.select { |w| w[:queues].any? { |q| q == "*" || q == queue } }

  # ─── записка — строка ───────────────────────────────────────────────────

  def test_the_note_is_a_row_the_morning_worker_will_find
    hand_in
    job = queued(:DispatchJob).first
    refute_nil job,
               "Записки нет в таблице очереди. Если адаптер очереди держит записки в памяти " \
               "(`:async`), перезапуск конторы их стирает: утром работнику нечего взять."
    ActiveRecord::Base.connection_handler.clear_active_connections!
    work_off!
    assert_equal ["ПАРОХОД ВЫШЕЛ"], line.accepted.map { |item| item[:body] }
  end

  # ─── своя очередь, свой работник ─────────────────────────────────────────

  def test_telegrams_wait_in_the_telegraph_queue
    hand_in
    assert_equal "telegraph", queued(:DispatchJob).first&.queue_name,
                 "Телеграммы лежат не в очереди `telegraph`. У телеграфа свой работник: линия " \
                 "принимает по одной, и телеграммы не должны стоять за чужой работой."
    work_off!(queues: "default")
    assert_empty line.accepted, "Работник прочих очередей отдал телеграмму на линию."
    work_off!(queues: "telegraph")
    assert_equal 1, line.accepted.size, "Работник телеграфа прошёл — линия ничего не приняла."
  end

  def test_the_telegraph_has_exactly_one_thread
    telegraph = listening("telegraph")
    refute_empty telegraph,
                 "Очередь `telegraph` не слушает ни один работник в config/queue.yml. Записки " \
                 "лягут и пролежат вечно."
    threads = telegraph.sum { |w| w[:threads] * w[:processes] }
    assert_equal 1, threads,
                 "Очередь `telegraph` слушает не один поток, а #{threads}. Линия принимает по одной: " \
                 "два потока отдадут две телеграммы наперегонки, и порядок передачи станет " \
                 "случайным. Работник со звёздочкой (`queues: \"*\"`) тоже слушает телеграф."
  end

  def test_every_queue_the_office_uses_has_a_worker
    Rails.application.eager_load!
    used = ApplicationJob.descendants.map { |job| job.new.queue_name }.uniq
    used.each do |queue|
      refute_empty listening(queue),
                   "Очередь `#{queue}` (#{ApplicationJob.descendants.select { |job| job.new.queue_name == queue }.join(", ")}) " \
                   "не слушает ни один работник config/queue.yml."
    end
    refute_empty listening("default"), "Очередь `default` не слушает никто — а в неё ложится работа Rails."
  end

  # ─── казна вперёд ────────────────────────────────────────────────────────

  def test_receipts_for_the_treasury_go_before_routine_telegrams
    shipment = delivery("NGS-0512")
    3.times { |i| DispatchJob.perform_later(telegram("ОБЫЧНАЯ #{i}")) }
    DispatchJob.perform_later(telegram("КВИТАНЦИЯ NGS-0512 КАЗНЕ", delivery: shipment))
    work_off!
    bodies = line.accepted.map { |item| item[:body] }
    assert_equal 4, bodies.size, "Работник прошёл по четырём запискам — линия приняла не четыре."
    assert_equal "КВИТАНЦИЯ NGS-0512 КАЗНЕ", bodies.first,
                 "Квитанция казне ушла не первой, а #{bodies.index("КВИТАНЦИЯ NGS-0512 КАЗНЕ").to_i + 1}-й. " \
                 "По квитанции платят: она идёт вперёд, даже если её отдали последней. Порядок " \
                 "решает приоритет записки."
    assert_equal ["ОБЫЧНАЯ 0", "ОБЫЧНАЯ 1", "ОБЫЧНАЯ 2"], bodies.drop(1),
                 "Обычные телеграммы ушли не в том порядке, в каком их отдали."
  end

  # ─── ночь ────────────────────────────────────────────────────────────────

  def test_a_telegram_handed_in_at_night_waits_for_the_morning
    travel_to at(12, 21, 30)
    hand_in("НОЧНАЯ")
    work_off!
    assert_equal [], line.accepted.map { |item| item[:body] },
                 "Телеграмма, поданная в 21:30, ушла на линию ночью. Станция принимает с 8 до 20: " \
                 "ночью работник будет долбить в закрытое окошко."
    travel_to at(13, 7, 59)
    work_off!
    assert_empty line.accepted, "Телеграмма ушла до открытия станции."
    travel_to at(13, 8, 0)
    work_off!
    assert_equal ["НОЧНАЯ"], line.accepted.map { |item| item[:body] },
                 "В 8:00 станция открылась, а телеграмма не ушла."
  end

  def test_before_the_opening_it_waits_until_eight_the_same_day
    travel_to at(12, 6, 15)
    hand_in("РАННЯЯ")
    job = queued(:DispatchJob).first
    assert_equal at(12, 8, 0), job&.scheduled_at&.in_time_zone,
                 "Телеграмма, поданная в 6:15, должна ждать 8:00 того же дня, а не следующего."
  end

  def test_in_working_hours_it_goes_at_once
    travel_to at(12, 19, 59)
    hand_in("ВЕЧЕРНЯЯ")
    work_off!
    assert_equal ["ВЕЧЕРНЯЯ"], line.accepted.map { |item| item[:body] },
                 "В 19:59 станция ещё открыта — телеграмма должна уйти сразу."
    travel_to at(12, 20, 0)
    hand_in("ПОЗДНЯЯ")
    work_off!
    assert_equal 1, line.accepted.size, "В 20:00 станция закрыта, а телеграмма ушла."
  end

  def test_the_night_note_is_in_the_table_not_in_memory
    travel_to at(12, 22, 0)
    hand_in("НОЧНАЯ")
    job = queued(:DispatchJob).first
    refute_nil job, "Ночной записки нет в таблице очереди."
    assert_equal 1, SolidQueue::ScheduledExecution.where(job_id: job.id).count,
                 "Ночная записка не отложена в очереди до утра. Спать в задаче (`sleep`) или " \
                 "держать таймер в памяти конторы — значит потерять записку при первом перезапуске."
  end

  def test_a_worker_who_died_holding_the_note_does_not_lose_it
    hand_in("ДО ОБРЫВА СВЕТА")
    SolidQueue::ReadyExecution.claim("*", 1, nil)
    work_off!
    assert_empty line.accepted, "Записку держит умерший работник — другой её не возьмёт, пока держит."
    restart!
    work_off!
    assert_equal ["ДО ОБРЫВА СВЕТА"], line.accepted.map { |item| item[:body] },
                 "После перезапуска записка умершего работника не вернулась в очередь."
  end
end
