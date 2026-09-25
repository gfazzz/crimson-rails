# CRIMSON RAILS — s06e10, проверка: один день под двумя датами.
#
# Сводка за день ставится расписанием, а не человеком. Проверяется то, что
# расписание обещает, и то, что сводка считает: задача есть в расписании,
# ставится в восемь по Владивостоку, одна на минуту, сколько бы надзирателей
# её ни ставили; сводит вчерашний владивостокский день — не гринвичский; одну
# квитанцию под двумя датами считает одним днём; поставленная дважды, лежит
# одна.

require_relative "../../support/check.rb"
require "erb"
require "yaml"

class ScheduleTest < Crimson::Test
  def setup
    wipe!
    @a = delivery("NGS-0719", arrived_on: Date.new(1892, 7, 23))
    @b = delivery("NGS-0720", arrived_on: Date.new(1892, 7, 22))
  end

  def vlad(day, hour, minute = 0) = Time.zone.local(1892, 7, day, hour, minute)

  def receipt(shipment, number, route, written_on)
    Acceptance.create!(delivery: shipment, line_number: number, route: route, signed_by: "Кувабара",
                       accepted_on: written_on)
  end

  def pay(shipment, at)
    Disbursement.create!(delivery: shipment, acceptance: shipment.acceptances.first || receipt(shipment, "X-#{shipment.id}", "cable", at.to_date),
                         kopecks: shipment.kopecks, paid_at: at)
  end

  def task
    file = File.join(Crimson.app, "config/recurring.yml")
    config = YAML.safe_load(ERB.new(File.read(file)).result, aliases: true)
    key, options = (config["production"] || {}).find { |_, item| item["class"] == "DailyReportJob" }
    flunk "В расписании продакшена (config/recurring.yml) нет задачи с классом DailyReportJob." unless key
    SolidQueue::RecurringTask.from_configuration(key, **options.symbolize_keys)
  end

  def report_for(day)
    DayReport.find_by(day: Date.new(1892, 7, day)) ||
      flunk("Сводки за #{day} июля нет. Работник прошёл, а в книге сводок пусто.")
  end

  def run_report(at:)
    travel_to at
    DailyReportJob.perform_later
    work_off!
  end

  # ─── расписание ─────────────────────────────────────────────────────────

  def test_the_report_is_in_the_schedule_at_eight_in_vladivostok
    travel_to vlad(23, 12)
    next_run = task.next_time.in_time_zone
    assert_equal vlad(24, 8), next_run,
                 "Следующая сводка по расписанию — #{next_run}, а не 8:00 24 июля по Владивостоку. " \
                 "«Восемь» — чьих часов: в расписании это должно быть сказано поясом или взято из " \
                 "пояса приложения."
  end

  def test_the_schedule_is_there_in_development_too
    file = File.join(Crimson.app, "config/recurring.yml")
    config = YAML.safe_load(ERB.new(File.read(file)).result, aliases: true)
    refute_nil (config["development"] || {}).values.find { |item| item["class"] == "DailyReportJob" },
               "В разработке расписания сводки нет: bin/jobs у конторы её не поставит."
  end

  def test_two_schedulers_one_note
    travel_to vlad(24, 8)
    2.times { task.enqueue(at: vlad(24, 8)) }
    assert_equal 1, queued(:DailyReportJob).size,
                 "Два надзирателя поставили сводку на одну и ту же минуту дважды."
  end

  def test_the_scheduled_note_reports_yesterday
    travel_to vlad(24, 8)
    task.enqueue(at: vlad(24, 8))
    work_off!
    assert_equal 1, report_for(23).arrived, "Сводка по расписанию 24 июля в 8:00 — не за 23 июля."
  end

  # ─── день — владивостокский ─────────────────────────────────────────────

  def test_yesterday_is_yesterday_in_vladivostok
    receipt(@a, "НГС-9001", "cable", Date.new(1892, 7, 23))
    pay(@a, vlad(23, 23, 30))
    pay(@b, vlad(24, 0, 30))
    run_report(at: vlad(24, 8))
    report = report_for(23)
    assert_equal 240_000, report.paid_kopecks,
                 "В сводке за 23 июля — выплата, сделанная 24-го в 0:30 по Владивостоку. По Гринвичу " \
                 "это ещё 23-е, 15:42: день сводки считают по часам конторы, а не по часам сервера."
  end

  def test_a_late_worker_still_reports_the_day_of_the_schedule
    travel_to vlad(24, 8)
    task.enqueue(at: vlad(24, 8))
    travel_to vlad(25, 0, 30)
    work_off!
    refute_nil DayReport.find_by(day: Date.new(1892, 7, 23)),
               "Работник взял сводку, поставленную в 8:00 24-го, только в 0:30 25-го — и свёл " \
               "не тот день. «Вчера» — от того, когда записку поставили, а не когда исполнили."
    assert_nil DayReport.find_by(day: Date.new(1892, 7, 24))
  end

  # ─── один день — две даты ───────────────────────────────────────────────

  def test_an_old_style_receipt_counts_on_its_real_day
    receipt(@a, "ИРК-0719", "overland", Date.new(1892, 7, 11))
    run_report(at: vlad(24, 8))
    assert_equal 1, report_for(23).receipts,
                 "Квитанция государственного телеграфа от 11 июля по старому стилю — это 23 июля " \
                 "по новому. В сводке за 23-е её нет."
    assert_nil DayReport.find_by(day: Date.new(1892, 7, 11))
  end

  def test_one_delivery_two_receipts_two_calendars_is_a_repeat
    receipt(@a, "НГС-9001", "cable", Date.new(1892, 7, 23))
    receipt(@a, "ИРК-0719", "overland", Date.new(1892, 7, 11))
    receipt(@b, "НГС-9002", "cable", Date.new(1892, 7, 23))
    receipt(delivery("NGS-0721"), "ИРК-0720", "overland", Date.new(1892, 7, 11))
    run_report(at: vlad(24, 8))
    report = report_for(23)
    assert_equal 4, report.receipts
    assert_equal 1, report.repeats,
                 "У NGS-0719 за 23 июля две квитанции — кабельная от 23-го и сухопутная от 11-го по " \
                 "старому стилю. Это один день: сводка должна видеть повтор. У NGS-0721 квитанция " \
                 "одна, пусть и сухопутная, — это не повтор."
  end

  def test_a_new_style_receipt_is_not_moved
    receipt(@a, "НГС-9001", "cable", Date.new(1892, 7, 11))
    run_report(at: vlad(24, 8))
    assert_equal 0, report_for(23).receipts,
                 "Кабельная квитанция от 11 июля — по новому стилю: это 11 июля, а не 23-е."
  end

  # ─── одна сводка на день ────────────────────────────────────────────────

  def test_a_report_twice_is_one_report
    run_report(at: vlad(24, 8))
    run_report(at: vlad(24, 8, 5))
    assert_equal 1, DayReport.where(day: Date.new(1892, 7, 23)).count,
                 "Сводку за 23 июля поставили дважды — легли две сводки."
    assert_equal 0, failed_jobs.size, "Вторая сводка за тот же день упала — а должна была заменить числа."
  end

  def test_a_second_run_brings_the_numbers_up_to_date
    run_report(at: vlad(24, 8))
    receipt(@a, "НГС-9003", "cable", Date.new(1892, 7, 23))
    run_report(at: vlad(24, 9))
    assert_equal 1, report_for(23).receipts,
                 "Сводку за 23 июля пересчитали после новой квитанции — а в ней старые числа."
  end

  def test_a_quiet_day_has_a_report_too
    run_report(at: vlad(21, 8))
    report = report_for(20)
    assert_equal [0, 0, 0, 0], [report.arrived, report.receipts, report.repeats, report.paid_kopecks],
                 "Сводка за тихий день — не пустое место, а нули."
  end
end
