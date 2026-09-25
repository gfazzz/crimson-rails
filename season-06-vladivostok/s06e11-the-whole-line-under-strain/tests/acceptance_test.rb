# CRIMSON RAILS — s06e11, приёмка сезона: вся линия под нагрузкой.
#
# Контракт сезона на всём сразу. Май 1892 года целиком, как он прошёл через
# контору: двенадцать пароходов, квитанции кабелем и сушей, квитанции,
# присланные дважды, линия, которая рвётся, теряет ответы и молчит,
# работник, умерший после выплаты, два работника разом. Потом — сутки, чтобы
# всё, что должно повториться, повторилось.
#
# Проверяется не код серий, а свойства конторы после такого месяца: каждая
# поставка оплачена ровно один раз, казначейство узнало о каждой выплате ровно
# один раз, ничего не застряло и не спрятано, копии не врут, табло
# показывает книгу, сводки лежат по одной на день, а сверка находит ровно то,
# что пришло из Лондона. Случайность — с зерном: прогон повторяем.

require_relative "../../support/check.rb"

class AcceptanceTest < Crimson::Test
  SEED = 1892
  PRICE = 240_000

  def setup
    wipe!
    @random = Random.new(SEED)
  end

  # ─── май ─────────────────────────────────────────────────────────────────

  def month_of_may
    travel_to Time.zone.local(1892, 5, 1, 9)
    shipments = (1..12).map do |i|
      delivery(format("NGS-05%02d", i), steamer: "Сумико-мару", kopecks: PRICE,
                                        arrived_on: Date.new(1892, 5, 2 * i))
    end
    work_off!

    # Табло, каким его открыли первого мая и больше не перезагружали.
    get path(:board)
    @board_on_the_first = response.body
    cable.clear

    # Линия этого месяца: два обрыва, один потерянный ответ, одна задумчивость.
    line.break!(2)
    line.lose_answer!
    line.stall!(1)

    london = shipments.sample(6, random: @random)
    twice = shipments.sample(3, random: @random)
    shipments.each_with_index do |shipment, index|
      day = shipment.arrived_on
      travel_to Time.zone.local(1892, day.month, day.day, 7)
      cable = { number: "НГС-#{7700 + index}", route: "cable", delivery: shipment.reference,
                signed_by: "Кувабара", accepted_on: day.iso8601 }
      line_posts(path(:receipts), cable)
      line_posts(path(:receipts), cable) if twice.include?(shipment)
      next unless london.include?(shipment)

      old_style = day.julian
      line_posts(path(:receipts), { number: "ИРК-#{300 + index}", route: "overland", delivery: shipment.reference,
                                    signed_by: "Кувабара", accepted_on: Date.new(old_style.year, old_style.month, old_style.day).iso8601 })
    end

    # Первый работник выплатил и умер; второй и третий берут две записки разом.
    crash_after_effect!(DisburseJob)
    restart!
    two_workers_at_once!(meet_at: "disbursements", job_class: DisburseJob)

    # Сутки: всё, что должно повториться, повторяется.
    24.times do
      travel 1.hour
      work_off!
    end

    (1..31).each { |day| DailyReportJob.perform_later(Date.new(1892, 5, day).iso8601) }
    work_off!

    treasury.book!("1892-05", Acceptance.includes(:delivery).map do |receipt|
      { delivery: receipt.delivery.reference, receipt: receipt.line_number, kopecks: PRICE }
    end)
    ReconcileJob.perform_later("1892-05")
    work_off!

    { shipments: shipments, london: london }
  end

  def outcome
    {
      paid: Disbursement.includes(:delivery, :acceptance).map { |d| [d.delivery.reference, d.acceptance.line_number] }.sort,
      overpaid: Overpayment.includes(:delivery).map { |o| [o.delivery.reference, o.receipt] }.sort,
      reports: DayReport.order(:day).pluck(:day, :arrived, :receipts, :repeats, :paid_kopecks)
    }
  end

  # ─── свойства конторы после мая ─────────────────────────────────────────

  def test_each_delivery_is_paid_exactly_once
    may = month_of_may
    counts = Disbursement.group(:delivery_id).count
    assert_equal may[:shipments].map(&:id).sort, counts.keys.sort,
                 "Не каждая поставка с квитанцией оплачена: после месяца под нагрузкой выплаты есть не у всех."
    assert_equal [1], counts.values.uniq,
                 "Поставки, оплаченные больше одного раза: #{counts.select { |_, n| n > 1 }.keys.inspect}."
    assert_equal 12 * PRICE, Disbursement.sum(:kopecks)
  end

  def test_the_treasury_hears_of_each_payment_once
    month_of_may
    notices = Telegram.where(addressee: "Казначейство постройки, Владивосток")
    assert_equal 12, notices.count, "Телеграмм казначейству о выплатах — не двенадцать."
    assert notices.all?(&:sent?), "Не все телеграммы о выплатах ушли на линию."
    on_the_line = line.accepted.select { |item| item[:body].to_s.start_with?("ВЫПЛАЧЕНО") }
    assert_equal 12, on_the_line.size,
                 "Линия передала #{on_the_line.size} телеграмм о выплатах вместо двенадцати: обрыв, " \
                 "потерянный ответ или повтор передали какую-то дважды."
    assert_equal notices.pluck(:number).sort, on_the_line.map { |item| item[:number] }.sort,
                 "Номера телеграмм в книге не те, что дала линия."
  end

  def test_nothing_is_stuck_and_nothing_is_hidden
    month_of_may
    assert_equal [], failed_jobs.map(&:class_name),
                 "После месяца в упавших лежат записки. Под нагрузкой контора не должна ронять ничего, " \
                 "кроме того, что надо чинить."
    assert_equal [], Telegram.pending.pluck(:body), "Телеграммы, застрявшие в очереди после суток."
    assert_equal 0, SolidQueue::ReadyExecution.count + SolidQueue::ScheduledExecution.count,
                 "После суток в очереди остались несделанные записки."
  end

  def test_the_copies_tell_the_truth
    month_of_may
    assert_equal Delivery.summary("1892-05"), Delivery.cached_summary("1892-05"),
                 "Копия сводки за май не совпадает со сводкой, сосчитанной заново."
    get path(:payout, "1892-05")
    tag = response.headers["ETag"]
    travel 1.hour
    Disbursement.first.update!(kopecks: PRICE - 100)
    get path(:payout, "1892-05"), headers: { "If-None-Match" => tag }
    assert_status 200, "Лист выплат поправили — а читающему ответили «у тебя уже есть»."
  end

  def test_the_board_shows_the_book
    may = month_of_may
    doc = board_after_everything
    may[:shipments].each do |shipment|
      state = doc.at_css("[id='#{ActionView::RecordIdentifier.dom_id(shipment)}'] [data-state]")&.text&.squish
      assert_equal "оплачено", state,
                   "Табло, открытое первого мая и ни разу не перезагруженное, показывает #{shipment.reference} " \
                   "как «#{state}». Всё, что изменилось за месяц, должно было прийти по кабелю."
    end
  end

  # Табло, открытое первого мая, после всего, что пришло по кабелю за месяц.
  def board_after_everything
    doc = page(@board_on_the_first)
    stream = listened(doc).first || flunk("Табло не слушает поток.")
    arrived = cabled(stream)
    missing = missing_stream_targets(doc, arrived)
    assert_empty missing, "По кабелю за май ушли действия с целями, которых на табло нет: #{missing.uniq.join(", ")}."
    apply_streams(doc, arrived)
  end

  def test_each_day_has_one_report_and_the_repeats_are_seen
    month_of_may
    assert_equal 31, DayReport.where(day: Date.new(1892, 5, 1)..Date.new(1892, 5, 31)).count,
                 "Сводок за май не тридцать одна."
    assert_equal 6, DayReport.sum(:repeats),
                 "Повторов за май в сводках не шесть: сводка не свела бланки двух календарей в один день."
    assert_equal 12 * PRICE, DayReport.sum(:paid_kopecks),
                 "Выплачено по сводкам за май не столько, сколько в книге выплат."
    paid = Disbursement.all.group_by { |d| d.paid_at.in_time_zone.to_date }.transform_values { |d| d.sum(&:kopecks) }
    assert_equal paid, DayReport.where.not(paid_kopecks: 0).pluck(:day, :paid_kopecks).to_h,
                 "Выплаты в сводках легли не в те дни, в которые их выплатили по Владивостоку."
  end

  def test_the_overpayments_are_what_london_sent
    may = month_of_may
    london = Acceptance.where(route: "overland").includes(:delivery).map { |r| [r.delivery.reference, r.line_number] }.sort
    assert_equal 6, london.size
    assert_equal london, outcome[:overpaid],
                 "Сверка нашла не те переплаты: переплата — каждая выплата казны по квитанции через " \
                 "Иркутск, и только они."
    get path(:overpayment, "1892-05")
    assert_equal "14 400 руб. 00 коп.", page.at_css("main [data-total]")&.text&.squish
    assert_equal may[:london].map(&:reference).sort, london.map(&:first)
  end

  def test_the_run_repeats
    month_of_may
    first = outcome
    wipe!
    @random = Random.new(SEED)
    line.reset!
    treasury.reset!
    cable.clear
    month_of_may
    assert_equal first, outcome, "Тот же май с тем же зерном дал другой итог. Прогон не повторяем."
  end
end
