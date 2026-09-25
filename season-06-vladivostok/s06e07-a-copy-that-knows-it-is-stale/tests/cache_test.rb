# CRIMSON RAILS — s06e07, проверка: копия, которая знает, что устарела.
#
# Кеш проверяется двумя свойствами сразу, и одно без другого ничего не
# стоит. Копия экономит работу: второй раз сводку не считают. И копия не
# врёт: стоит поправить, добавить или убрать строку в любой из книг, из
# которых сводка сосчитана, — и следующий читатель видит новые числа.
# Экономию видно по запросам к базе, правду — по странице.

require_relative "../../support/check.rb"

class CacheTest < Crimson::Test
  def setup
    wipe!
    ActionController::Base.perform_caching = true
    @a = delivery("NGS-0512", arrived_on: Date.new(1892, 5, 3))
    @b = delivery("NGS-0513", sleepers: 3_000, kopecks: 180_000, arrived_on: Date.new(1892, 5, 17))
    receipt(@a, "НГС-7712", "cable", Date.new(1892, 5, 2))
    receipt(@b, "НГС-7713", "cable", Date.new(1892, 5, 16))
    receipt(@a, "ИРК-0331", "overland", Date.new(1892, 5, 14))
  end

  def teardown
    ActionController::Base.perform_caching = false
  end

  def receipt(shipment, number, route, on)
    Acceptance.create!(delivery: shipment, line_number: number, route: route, signed_by: "Кувабара", accepted_on: on)
  end

  def summary(month = "1892-05")
    get path(:summary, month)
    assert_status 200
    %w[steamers sleepers cable overland paid].to_h do |name|
      [name.to_sym, page.at_css("main [data-#{name}]")&.text&.squish ||
        flunk("На сводке нет строки «#{name}».")]
    end
  end

  # Запросы, которые считают: GROUP BY, SUM. Сколько строк и когда правили —
  # не счёт, а вопрос «не устарела ли копия»; он дешёв и должен остаться.
  def counting(&block)
    queries(nil, &block).grep(/GROUP BY|SUM\(/i)
  end

  # ─── где лежит копия ────────────────────────────────────────────────────

  def test_the_copy_lives_in_the_table
    assert_kind_of SolidCache::Store, Rails.cache,
                   "Кеш приложения в проверках — #{Rails.cache.class}. Копия должна лежать там же, " \
                   "где на проде, — в таблице Solid Cache; `:null_store` ничего не хранит, и " \
                   "проверять его — значит проверять, что кеша нет."
    summary
    refute_empty SolidCache::Entry.all, "Сводку прочли, а в таблице кеша пусто."
  end

  # ─── копия экономит ─────────────────────────────────────────────────────

  def test_the_summary_is_right
    assert_equal({ steamers: "2", sleepers: "7000", cable: "2", overland: "1", paid: "0 руб. 00 коп." }, summary)
  end

  def test_the_second_reader_does_not_count_again
    first = counting { summary }
    refute_empty first, "Сводка не сосчитана вовсе — на странице числа ниоткуда."
    second = counting { summary }
    assert_empty second,
                 "Сводку прочли второй раз — и сосчитали заново (#{second.size} запросов со счётом). " \
                 "Копия, которой не пользуются, — не копия."
  end

  # ─── копия не врёт ──────────────────────────────────────────────────────

  def test_a_new_receipt_makes_the_copy_stale
    summary
    receipt(@b, "ИРК-0332", "overland", Date.new(1892, 5, 20))
    assert_equal "2", summary[:overland],
                 "Квитанция добавлена, а сводка показывает старое число. Копия не знает, что устарела."
  end

  def test_a_removed_receipt_makes_the_copy_stale
    summary
    Acceptance.find_by(line_number: "ИРК-0331").destroy!
    assert_equal "0", summary[:overland],
                 "Квитанцию убрали из книги, а сводка всё ещё её считает. Время последней правки от " \
                 "удаления не меняется — версия книги должна знать и число строк."
  end

  def test_an_edited_receipt_makes_the_copy_stale
    summary
    travel 1.minute
    Acceptance.find_by(line_number: "НГС-7713").update!(route: "overland", line_number: "ИРК-0340")
    result = summary
    assert_equal ["1", "2"], [result[:cable], result[:overland]],
                 "Квитанцию поправили, а сводка показывает, как было."
  end

  def test_a_payment_makes_the_copy_stale
    summary
    Disbursement.create!(delivery: @a, acceptance: @a.acceptances.first, kopecks: 240_000, paid_at: Time.current)
    assert_equal "2 400 руб. 00 коп.", summary[:paid],
                 "Казна выплатила, а сводка показывает ноль."
  end

  def test_an_arrival_makes_the_copy_stale
    summary
    delivery("NGS-0514", arrived_on: Date.new(1892, 5, 30))
    assert_equal "3", summary[:steamers], "Пароход пришёл, а в сводке его нет."
  end

  def test_each_month_has_its_own_copy
    delivery("NGS-0601", arrived_on: Date.new(1892, 6, 4))
    assert_equal "2", summary("1892-05")[:steamers]
    assert_equal "1", summary("1892-06")[:steamers], "Сводка за июнь показала майскую копию."
  end

  # ─── строки книги поставок ──────────────────────────────────────────────

  def rows
    get path(:deliveries)
    assert_status 200
    page.css("main tbody tr").to_h do |row|
      [row.at_css("th")&.text&.squish, [row.at_css("[data-receipts]")&.text&.squish, row.at_css("[data-paid]")&.text&.squish]]
    end
  end

  def test_each_row_is_a_copy
    rows
    second = queries("acceptances") { rows }
    assert_empty second,
                 "Книгу поставок прочли второй раз — и для каждой строки снова спросили квитанции. " \
                 "Строка поставки — копия (`cache`), и спрашивать её книги, пока она верна, незачем."
  end

  def test_a_new_receipt_refreshes_its_row
    rows
    travel 1.minute
    receipt(@b, "ИРК-0332", "overland", Date.new(1892, 5, 20))
    assert_equal "2", rows["NGS-0513"]&.first,
                 "У поставки новая квитанция, а строка книги показывает старое число. Копия строки " \
                 "привязана к поставке; квитанция поставку не тронула (`touch`), и копия не устарела."
    assert_equal "2", rows["NGS-0512"]&.first
  end

  def test_a_payment_refreshes_its_row
    rows
    travel 1.minute
    Disbursement.create!(delivery: @a, acceptance: @a.acceptances.first, kopecks: 240_000, paid_at: Time.current)
    assert_equal "2 400 руб. 00 коп.", rows["NGS-0512"]&.last,
                 "Поставка оплачена, а строка книги показывает прочерк."
  end
end
