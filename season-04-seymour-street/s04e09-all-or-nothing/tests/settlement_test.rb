# CRIMSON RAILS — s04e09, проверка.
#
# Счёт идёт по нескольким строкам сразу. Проверяется не то, что он верен, — это
# арифметика, — а то, что он ложится целиком или не ложится вовсе, что повтор
# даёт тот же итог, и что выплата случается один раз даже из устаревшей копии.

require_relative "../../support/check.rb"

class SettlementTest < Crimson::Test
  def setup
    wipe!("settlements", "legs", "consignments", "companies")
    @gnr = Company.create!(code: "GNR", name: "Великая северная")
    @ner = Company.create!(code: "NER", name: "Северо-восточная")
  end

  # Перевозка на 240 пенсов: 12 миль у GNR и 108 у NER.
  def shipment(reference: "B-1", on: "1891-08-19", pence: 240)
    record = Consignment.create!(**bill(company_id: @gnr.id, reference: reference,
                                        sent_on: on, pence: pence))
    Leg.create!(consignment: record, company: @gnr, position: 1, miles: 12, role: :collected)
    Leg.create!(consignment: record, company: @ner, position: 2, miles: 108, role: :delivered)
    record
  end

  # ─── ведомость расчётов ─────────────────────────────────────────────────

  def test_settlements_exist_with_exactly_these_columns
    assert table?("settlements"), "Таблицы settlements нет."
    assert_equal %w[company_id created_at id lock_version pence period state updated_at],
                 columns_after("CreateSettlements", "settlements"),
                 "Состав столбцов не тот: дорога, месяц, сумма, состояние, счётчик правок и " \
                 "две даты."
  end

  def test_one_settlement_per_road_per_month
    index = index_on("settlements", "company_id", "period")
    refute_nil index, "Нет составного индекса по паре «дорога + месяц»."
    assert index.unique,
           "Индекс не уникальный. Пересчёт, начатый дважды, даст две строки — и Палата " \
           "заплатит дважды."
  end

  def test_the_link_and_the_conditions_are_there
    refute_nil foreign_key("settlements", "companies")
    refute column("settlements", "pence").null
    names = check_constraints("settlements").map { |item| item.name.to_s }
    assert_operator names.length, :>=, 2, "Условия на сумму и на состояние."
    assert_empty names.select { |name| name.empty? || name.start_with?("chk_rails_") }
  end

  def test_the_version_counter_is_there
    column = column("settlements", "lock_version")
    assert_equal :integer, column.type,
                 "Счётчик правок — целое. Имя `lock_version` не произвольное: по нему Rails " \
                 "и узнаёт столбец."
    refute column.null
    assert_equal "0", column.default.to_s
  end

  # ─── счёт ───────────────────────────────────────────────────────────────

  def test_shares_are_split_by_miles
    shipment
    shares = Settlement.shares_for("1891-08")
    assert_equal 24, shares[@gnr.id], "12 миль из 120 при плате 240 — двадцать четыре пенса."
    assert_equal 216, shares[@ner.id]
  end

  def test_settle_writes_a_row_per_road
    shipment
    Settlement.settle!("1891-08")
    assert_equal 2, count("settlements")
    assert_equal 24, Settlement.find_by(company: @gnr, period: "1891-08").pence
    assert_equal "pending", Settlement.find_by(company: @ner, period: "1891-08").state
  end

  def test_settle_marks_the_consignments
    record = shipment
    Settlement.settle!("1891-08")
    assert record.reload.settled?, "Отметка о расчёте ставится в той же проводке."
  end

  def test_settle_only_takes_its_month
    shipment(reference: "B-AUG", on: "1891-08-19")
    shipment(reference: "B-SEP", on: "1891-09-02")
    Settlement.settle!("1891-08")
    assert_equal 24, Settlement.find_by(company: @gnr, period: "1891-08").pence,
                 "Сентябрьская перевозка в августовский расчёт попасть не должна."
  end

  # ─── повтор даёт то же ──────────────────────────────────────────────────

  def test_settling_twice_does_not_double
    shipment
    Settlement.settle!("1891-08")
    Settlement.settle!("1891-08")

    assert_equal 2, count("settlements"),
                 "Второй пересчёт завёл вторые строки. Расчёт ищут по паре «дорога + месяц», " \
                 "а не заводят заново."
    assert_equal 24, Settlement.find_by(company: @gnr, period: "1891-08").pence
  end

  def test_settling_again_picks_up_new_consignments
    shipment(reference: "B-1")
    Settlement.settle!("1891-08")
    shipment(reference: "B-2")
    Settlement.settle!("1891-08")
    assert_equal 48, Settlement.find_by(company: @gnr, period: "1891-08").pence,
                 "Пересчёт обновляет сумму, а не складывает её с прежней."
    assert_equal 2, count("settlements")
  end

  # ─── всё или ничего ─────────────────────────────────────────────────────

  def test_a_failed_settlement_writes_nothing_at_all
    shipment
    Settlement.settle!("1891-08")
    Settlement.find_by(company: @ner, period: "1891-08").pay!

    # Пришёл ещё один бланк за август. Пересчёт должен упасть: расчёт с NER
    # уже оплачен, и переписывать его сумму нельзя.
    shipment(reference: "B-2")

    assert_raises(ActiveRecord::RecordInvalid) { Settlement.settle!("1891-08") }

    assert_equal 24, Settlement.find_by(company: @gnr, period: "1891-08").pence,
                 "Сумма первой дороги изменилась, хотя проводка упала. Значит счёт идёт не " \
                 "одной проводкой, и у Палаты остался месяц, посчитанный наполовину."
    assert_equal 216, Settlement.find_by(company: @ner, period: "1891-08").pence
  end

  def test_a_failed_settlement_leaves_the_consignments_unmarked
    shipment
    Settlement.settle!("1891-08")
    Settlement.find_by(company: @ner, period: "1891-08").pay!
    Consignment.update_all(settled: false)

    fresh = shipment(reference: "B-2")
    assert_raises(ActiveRecord::RecordInvalid) { Settlement.settle!("1891-08") }

    refute fresh.reload.settled?,
           "Отметка о расчёте осталась, хотя расчёт не состоялся. Откат обязан снять и её: " \
           "проводка одна."
  end

  def test_a_raise_inside_a_transaction_rolls_everything_back
    shipment
    assert_raises(RuntimeError) do
      Settlement.transaction do
        Settlement.settle!("1891-08")
        raise "телеграф оборвался"
      end
    end
    assert_equal 0, count("settlements"),
                 "Проводка, прерванная исключением, не оставляет следов — включая ту, что " \
                 "была внутри неё."
  end

  # ─── выплата случается один раз ─────────────────────────────────────────

  def test_paying_happens_inside_a_transaction
    shipment
    Settlement.settle!("1891-08")
    record = Settlement.find_by(company: @gnr, period: "1891-08")

    assert_operator transactions { record.pay! }, :>=, 1,
                    "Выплата идёт без проводки. Перечитать строку мало: между чтением и " \
                    "записью открывается то же окно, что в s04e04, — читать надо под " \
                    "блокировкой, а блокировка живёт только внутри проводки."
  end

  def test_paying_twice_is_refused
    shipment
    Settlement.settle!("1891-08")
    record = Settlement.find_by(company: @gnr, period: "1891-08")

    record.pay!
    assert record.reload.paid?
    assert_raises(Settlement::AlreadyPaid) { record.pay! }
  end

  def test_paying_from_a_stale_copy_is_refused_too
    shipment
    Settlement.settle!("1891-08")
    id = Settlement.find_by(company: @gnr, period: "1891-08").id

    here = Settlement.find(id)
    there = Settlement.find(id)   # вторая копия той же строки, взята раньше

    here.pay!

    assert_raises(Settlement::AlreadyPaid,
                  "Вторая копия заплатила ещё раз. Она смотрела в своё «уже оплачен?» — в то, " \
                  "что было верно минуту назад. Перед решением строку перечитывают, и " \
                  "перечитывают под блокировкой.") do
      there.pay!
    end
    assert_equal 1, db.select_value("SELECT COUNT(*) FROM settlements WHERE state = 1").to_i
  end

  def test_a_stale_copy_cannot_overwrite_a_fresh_change
    shipment
    Settlement.settle!("1891-08")
    id = Settlement.find_by(company: @gnr, period: "1891-08").id

    here = Settlement.find(id)
    there = Settlement.find(id)

    here.update!(pence: 100)

    assert_raises(ActiveRecord::StaleObjectError,
                  "Устаревшая копия переписала свежую правку молча. Счётчик правок для того и " \
                  "нужен: запись из копии, снятой до чужой правки, отвергается.") do
      there.update!(pence: 200)
    end
    assert_equal 100, Settlement.find(id).pence
  end

  def test_the_paid_sum_is_final
    shipment
    Settlement.settle!("1891-08")
    record = Settlement.find_by(company: @gnr, period: "1891-08")
    record.pay!

    refute record.update(pence: 999), "Оплаченный расчёт не переписывают: деньги уже ушли."
    refute_empty record.errors[:base]
  end

  # ─── прежнее цело ───────────────────────────────────────────────────────

  def test_model_says_taken_for_a_month_already_settled
    shipment
    Settlement.settle!("1891-08")
    twin = Settlement.new(company: @gnr, period: "1891-08", pence: 1)
    refute twin.valid?, "Второй расчёт с той же дорогой за тот же месяц."
    refute_empty twin.errors[:period]
  end

  def test_removing_a_road_with_settlements_is_refused
    # Дорога без перевозок и участков — только расчёт. Иначе отказ пришёл бы
    # от правила про участки, и про расчёты мы бы ничего не узнали.
    lonely = Company.create!(code: "CAL", name: "Каледонская")
    Settlement.create!(company: lonely, period: "1891-08", pence: 500)

    refute lonely.destroy, "Дорогу, которой Палата должна, из реестра не убирают."
    refute_empty lonely.errors[:base]
    assert Company.exists?(lonely.id)
  end

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments", "legs", "settlements"
  end
end
