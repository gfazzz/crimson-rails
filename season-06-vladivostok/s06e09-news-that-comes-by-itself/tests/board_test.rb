# CRIMSON RAILS — s06e09, проверка: новость, которая приходит сама.
#
# Табло не спрашивают — оно узнаёт само. Проверяется протокол целиком, как в
# s05e09, только поток приходит не в ответ на форму, а по кабелю: страница
# слушает поток с верным подписанным именем; после работника по этому потоку
# уходит действие Turbo; его цель есть на странице; приложенное к странице,
# оно даёт то, что стало в книгах. Кабель в проверках — адаптер `test`: он
# запоминает всё, что ушло.

require_relative "../../support/check.rb"
require "erb"
require "yaml"

class BoardTest < Crimson::Test
  def setup
    wipe!
    @a = delivery("NGS-0512", arrived_on: Date.new(1892, 7, 14))
    @b = delivery("NGS-0513", steamer: "Кодзё-мару")
    work_off!
    cable.clear
  end

  def board
    get path(:board)
    assert_status 200
    page
  end

  def pier
    listened(board).first ||
      flunk("Табло не слушает ни одного потока: на странице нет `turbo_stream_from`.")
  end

  def state_of(doc, shipment)
    doc.at_css("[id='#{ActionView::RecordIdentifier.dom_id(shipment)}'] [data-state]")&.text&.squish
  end

  # Табло, каким оно стало после того, что ушло по кабелю.
  def board_after_cable
    doc = board
    arrived = cabled(pier)
    refute_empty arrived, "Работник прошёл, а по кабелю на табло ничего не ушло."
    missing = missing_stream_targets(doc, arrived)
    assert_empty missing,
                 "По кабелю ушли действия с целями, которых на табло нет: #{missing.join(", ")}. " \
                 "Turbo молча ничего не сделает, и табло не изменится."
    apply_streams(doc, arrived)
  end

  # Квитанция в книге — без выплаты: выплату здесь не зовут.
  def receipt(shipment, number = "НГС-7712")
    Acceptance.create!(delivery: shipment, route: "cable", line_number: number,
                       signed_by: "Кувабара", accepted_on: Date.new(1892, 7, 15))
  end

  # ─── табло ───────────────────────────────────────────────────────────────

  def test_the_board_shows_where_each_delivery_is
    doc = board
    assert_equal "у причала", state_of(doc, @a)
    assert_equal "в море", state_of(doc, @b)
  end

  def test_the_board_listens_to_a_signed_stream
    doc = board
    source = doc.at_css("turbo-cable-stream-source")
    refute_nil source, "Табло не подписано ни на какой поток."
    assert_equal "Turbo::StreamsChannel", source["channel"]
    refute_nil pier,
               "Подпись имени потока на табло не проходит проверку сервера. Имя потока в разметке " \
               "подписывает сервер (`turbo_stream_from`) — иначе любая страница подпишется на что угодно."
  end

  # ─── новость приходит сама ──────────────────────────────────────────────

  def test_a_receipt_reaches_the_board_by_itself
    receipt(@a)
    work_off!
    assert_equal "квитанция", state_of(board_after_cable, @a),
                 "По кабелю пришло не то: строка поставки на табло не показывает квитанцию."
  end

  def test_a_payment_reaches_the_board_by_itself
    Acceptance.receive!(delivery: @a, route: "cable", line_number: "НГС-7712",
                        signed_by: "Кувабара", accepted_on: Date.new(1892, 7, 15))
    work_off!
    refute_empty Disbursement.where(delivery: @a), "Работник не выплатил: s06e04 должна быть зелёной."
    assert_equal "оплачено", state_of(board_after_cable, @a),
                 "Поставка оплачена, а по кабелю на табло пришло не «оплачено»."
  end

  def test_an_arrival_reaches_the_board_by_itself
    travel 1.minute
    @b.update!(arrived_on: Date.new(1892, 7, 15))
    work_off!
    doc = board_after_cable
    assert_equal "у причала", state_of(doc, @b)
    assert_equal "у причала", state_of(doc, @a), "Пароход NGS-0513 пришёл — а строка NGS-0512 изменилась."
  end

  def test_a_new_delivery_appears_on_the_board
    fresh = delivery("NGS-0514", steamer: "Хакодатэ-мару")
    work_off!
    doc = board_after_cable
    assert_equal "в море", state_of(doc, fresh), "Новая поставка не появилась на табло."
    assert_equal 3, doc.css("tbody tr").size,
                 "На табло не три строки: новая поставка заменила чужую или легла дважды."
  end

  # ─── кто рисует и когда ─────────────────────────────────────────────────

  def test_the_one_who_edits_does_not_draw_the_board
    travel 1.minute
    @b.update!(arrived_on: Date.new(1892, 7, 15))
    assert_empty cable.broadcasts(pier),
                 "Строку табло нарисовали и отправили прямо при правке. Правит конторщик или " \
                 "запрос линии — и ждёт, пока рисуется и уходит табло. Рисует работник " \
                 "(`broadcast_…_later_to`)."
    work_off!
    refute_empty cable.broadcasts(pier), "Работник прошёл — по кабелю ничего не ушло."
  end

  def test_an_edit_that_did_not_stay_sends_nothing
    Delivery.transaction do
      @b.update!(arrived_on: Date.new(1892, 7, 15))
      raise ActiveRecord::Rollback
    end
    work_off!
    assert_empty cable.broadcasts(pier),
                 "Правка откатилась, а табло получило новость о ней. Новость уходит после того, " \
                 "как правка легла (`after_…_commit`)."
    assert_equal "в море", state_of(board, @b)
  end

  # ─── кабель между процессами ─────────────────────────────────────────────

  def test_the_cable_joins_the_worker_and_the_server
    file = File.join(Crimson.app, "config/cable.yml")
    config = YAML.safe_load(ERB.new(File.read(file)).result, aliases: true)
    %w[development production].each do |env|
      adapter = config.dig(env, "adapter")
      refute_equal "async", adapter,
                   "Кабель в #{env} — `async`: он передаёт новости только внутри одного процесса. " \
                   "Строку табло рисует работник (bin/jobs), а браузер слушает сервер (bin/rails " \
                   "server) — новость до табло не дойдёт."
      refute_nil adapter, "У кабеля в #{env} нет адаптера."
    end
  end
end
