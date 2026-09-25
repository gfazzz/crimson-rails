# CRIMSON RAILS — s06e11, проверка: сверка с казначейством.
#
# Казна платит по квитанции, контора — по поставке. Сверка берёт книгу
# казначейства у чужой системы и кладёт в книгу переплат всё, что казна
# выплатила за поставку сверх одного раза. Проверяется то же, что весь
# сезон: эффект на любое число исполнений, обрыв и молчание чужой стороны,
# расписание с поясом.

require_relative "../../support/check.rb"
require "erb"
require "yaml"

class ReconcileTest < Crimson::Test
  def setup
    wipe!
    @a = delivery("NGS-0512")
    @b = delivery("NGS-0513")
    @c = delivery("NGS-0514")
    paid(@a, "НГС-7712")
    paid(@b, "НГС-7713")
    treasury.book!("1892-05", [
      { delivery: "NGS-0512", receipt: "НГС-7712", kopecks: 240_000 },
      { delivery: "NGS-0512", receipt: "ИРК-0331", kopecks: 240_000 },
      { delivery: "NGS-0513", receipt: "ИРК-0332", kopecks: 240_000 },
      { delivery: "NGS-0513", receipt: "НГС-7713", kopecks: 240_000 },
      { delivery: "NGS-0514", receipt: "НГС-7714", kopecks: 240_000 }
    ])
  end

  def paid(shipment, number)
    receipt = Acceptance.create!(delivery: shipment, route: "cable", line_number: number,
                                 signed_by: "Кувабара", accepted_on: Date.new(1892, 5, 20))
    Disbursement.create!(delivery: shipment, acceptance: receipt, kopecks: shipment.kopecks, paid_at: Time.current)
  end

  def reconcile(month = "1892-05")
    ReconcileJob.perform_later(month)
    work_off!
  end

  def overpaid = Overpayment.order(:id).map { |row| [row.delivery.reference, row.receipt] }

  def live_through(duration, step: 5.minutes)
    (duration / step).to_i.times do
      travel step
      work_off!
    end
  end

  # ─── что такое переплата ────────────────────────────────────────────────

  def test_what_the_treasury_paid_twice_is_an_overpayment
    reconcile
    assert_equal [%w[NGS-0512 ИРК-0331], %w[NGS-0513 ИРК-0332]].sort, overpaid.sort,
                 "Переплаты не те. За NGS-0512 и NGS-0513 казна платила дважды; своя выплата — по " \
                 "той квитанции, по которой платила контора, остальное — переплата. За NGS-0514 — " \
                 "один раз, и это не переплата."
    assert_equal [240_000, 240_000], Overpayment.order(:id).pluck(:kopecks)
  end

  def test_the_kept_payment_is_the_one_the_office_paid
    reconcile
    refute_includes overpaid, %w[NGS-0513 НГС-7713],
                    "Переплатой названа выплата казны по той же квитанции, по которой выплатила " \
                    "контора. Лишняя — вторая, иркутская, хотя в книге казначейства она раньше."
  end

  def test_the_page_shows_the_total
    reconcile
    get path(:overpayment, "1892-05")
    assert_status 200
    assert_equal "4 800 руб. 00 коп.", page.at_css("main [data-total]")&.text&.squish,
                 "На странице переплат не та сумма."
  end

  # ─── сверка дважды ──────────────────────────────────────────────────────

  def test_reconciling_twice_is_reconciling_once
    reconcile
    reconcile
    assert_equal 2, Overpayment.count, "Сверку поставили дважды — переплат стало вдвое больше."
    assert_equal 0, failed_jobs.size, "Вторая сверка упала — а должна была кончиться ничем."
  end

  def test_a_corrected_treasury_book_corrects_the_overpayment
    reconcile
    treasury.reset!
    treasury.book!("1892-05", [
      { delivery: "NGS-0512", receipt: "НГС-7712", kopecks: 240_000 },
      { delivery: "NGS-0512", receipt: "ИРК-0331", kopecks: 120_000 },
      { delivery: "NGS-0513", receipt: "ИРК-0332", kopecks: 240_000 },
      { delivery: "NGS-0513", receipt: "НГС-7713", kopecks: 240_000 }
    ])
    reconcile
    assert_equal 120_000, Overpayment.joins(:delivery).find_by(receipt: "ИРК-0331")&.kopecks,
                 "Казначейство поправило сумму в своей книге, а переплата после второй сверки — прежняя. " \
                 "Вторая сверка заменяет числа, а не пропускает то, что уже записано."
    assert_equal 2, Overpayment.count
  end

  def test_the_book_itself_refuses_a_second_copy
    reconcile
    row = Overpayment.first
    assert_raises(ActiveRecord::RecordNotUnique,
                  "База приняла вторую переплату с той же поставкой и квитанцией") do
      Overpayment.create!(delivery: row.delivery, receipt: row.receipt, month: row.month, kopecks: row.kopecks)
    end
  end

  # ─── чужая книга ────────────────────────────────────────────────────────

  def test_a_closed_treasury_is_tried_again
    treasury.break!(2)
    ReconcileJob.perform_later("1892-05")
    work_off!
    assert_equal 0, Overpayment.count
    assert_equal 0, failed_jobs.size, "Казначейство закрыто — и сверка легла в упавшие, а не в повтор."
    live_through(1.hour)
    assert_equal 2, Overpayment.count, "Казначейство открылось, а сверки так и нет."
  end

  def test_a_silent_treasury_does_not_hold_the_worker
    treasury.stall!(4)
    ReconcileJob.perform_later("1892-05")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    work_off!
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 3.5,
                    "Казначейство молчало, и работник ждал #{elapsed.round(1)} с. Чужой книге дают " \
                    "предел ожидания, как линии (s06e05)."
  end

  # ─── расписание ─────────────────────────────────────────────────────────

  def test_the_reconciliation_is_scheduled_on_the_first_for_the_month_before
    file = File.join(Crimson.app, "config/recurring.yml")
    config = YAML.safe_load(ERB.new(File.read(file)).result, aliases: true)
    key, options = (config["production"] || {}).find { |_, item| item["class"] == "ReconcileJob" }
    flunk "В расписании продакшена нет сверки (ReconcileJob)." unless key
    task = SolidQueue::RecurringTask.from_configuration(key, **options.symbolize_keys)
    travel_to Time.zone.local(1892, 5, 20, 12)
    assert_equal Time.zone.local(1892, 6, 1, 9), task.next_time.in_time_zone,
                 "Следующая сверка по расписанию — не 1 июня в 9:00 по Владивостоку."
    travel_to Time.zone.local(1892, 6, 1, 9)
    task.enqueue(at: Time.zone.local(1892, 6, 1, 9))
    work_off!
    assert_equal 2, Overpayment.where(month: "1892-05").count,
                 "Сверка по расписанию 1 июня свела не май."
  end
end
