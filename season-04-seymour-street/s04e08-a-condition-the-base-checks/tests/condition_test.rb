# CRIMSON RAILS — s04e08, проверка.
#
# Те же правила, что стоят в моделях с третьей серии, — но теперь их спрашивают
# у базы. Проверка вставляет сырым SQL то, чего не бывает: отрицательную плату,
# нулевые мили, роль, которой нет, и второго принявшего на одной перевозке.

require_relative "../../support/check.rb"

class ConditionTest < Crimson::Test
  def setup
    wipe!("legs", "consignments", "companies")
    @gnr = Company.create!(code: "GNR", name: "Великая северная")
    @ner = Company.create!(code: "NER", name: "Северо-восточная")
  end

  def shipment(reference: "B-1041")
    Consignment.create!(**bill(company_id: @gnr.id, reference: reference))
  end

  def leg_row(record, **over)
    { consignment_id: record.id, company_id: @gnr.id, position: 1, miles: 12 }.merge(over)
  end

  def refused(reason, &block)
    assert_raises(ActiveRecord::StatementInvalid, ActiveRecord::RecordNotUnique, reason, &block)
  end

  # ─── роль участка ───────────────────────────────────────────────────────

  def test_role_is_a_required_number_with_a_default
    assert_equal :integer, column("legs", "role").type,
                 "Роль хранится числом: у неё есть порядок, и число занимает меньше места, " \
                 "чем строка, повторённая миллион раз."
    refute column("legs", "role").null
    assert_equal "1", column("legs", "role").default.to_s,
                 "Умолчание должно быть «вёз»: это единственная роль, которая бывает у любого " \
                 "числа участков. Умолчание, которое нарушается самим фактом второй строки, — " \
                 "плохое умолчание."
  end

  def test_the_model_gives_the_numbers_names
    assert_equal({ "collected" => 0, "hauled" => 1, "delivered" => 2 }, Leg.roles,
                 "Три роли: принял, вёз, сдал.")
    record = shipment
    leg = Leg.create!(consignment: record, company: @gnr, position: 1, miles: 12)
    assert leg.hauled?, "Умолчание должно читаться именем, а не числом."
    leg.collected!
    assert_equal "collected", leg.reload.role
    assert_equal [leg], Leg.collected.to_a, "`enum` даёт и отбор."
  end

  def test_the_base_knows_there_are_exactly_three
    record = shipment
    [3, 7, -1].each do |unknown|
      refused("База приняла роль #{unknown}. Ролей три, и четвёртой не бывает: `enum` — " \
              "договорённость внутри приложения, а такая строка приедет мимо модели и сломает " \
              "всякий разбор по ролям.") do
        insert("legs", **leg_row(record, role: unknown))
      end
    end
  end

  def test_the_model_refuses_an_unknown_role_too
    record = shipment
    assert_raises(ArgumentError) { Leg.create!(consignment: record, company: @gnr, position: 1, miles: 12, role: "стоял") }
  end

  # ─── ровно один принявший ───────────────────────────────────────────────

  def test_there_is_a_partial_index_on_the_collector
    index = db.indexes("legs").find { |item| item.columns == %w[consignment_id] && item.unique }
    refute_nil index,
               "Нет уникального индекса по перевозке. Принявший участок в ней один."
    refute_nil index.where,
               "Индекс уникален по всей ведомости. Тогда у перевозки вообще не может быть " \
               "второго участка — а везущих бывает сколько угодно. Уникальность нужна не " \
               "всегда, а при условии; это умеет частичный индекс."
    assert_match(/role/, index.where.to_s)
  end

  def test_base_refuses_a_second_collector_on_the_same_consignment
    record = shipment
    insert("legs", **leg_row(record, position: 1, role: 0))
    refused("На одной перевозке два принявших участка. Тогда непонятно, кто принял груз.") do
      insert("legs", **leg_row(record, position: 2, role: 0, company_id: @ner.id))
    end
  end

  def test_a_second_hauling_leg_is_fine
    record = shipment
    insert("legs", **leg_row(record, position: 1, role: 0))
    insert("legs", **leg_row(record, position: 2, role: 1, company_id: @ner.id))
    assert insert("legs", **leg_row(record, position: 3, role: 1)),
           "Везущих участков бывает сколько угодно: частичный индекс сужает уникальность, а " \
           "не запрещает строки."
    assert_equal 3, count("legs")
  end

  def test_a_collector_on_another_consignment_is_fine
    one = shipment(reference: "B-1")
    two = shipment(reference: "B-2")
    insert("legs", **leg_row(one, role: 0))
    assert insert("legs", **leg_row(two, role: 0))
  end

  def test_the_model_says_taken_before_the_base_does
    record = shipment
    Leg.create!(consignment: record, company: @gnr, position: 1, miles: 12, role: :collected)
    twin = Leg.new(consignment: record, company: @ner, position: 2, miles: 31, role: :collected)
    refute twin.valid?, "Второй принявший должен получить отказ от модели."
    refute_empty twin.errors[:role]
    assert Leg.new(consignment: record, company: @ner, position: 2, miles: 31, role: :hauled).valid?,
           "А второй везущий — годен."
  end

  # ─── суммы, которых не бывает ───────────────────────────────────────────

  def test_base_refuses_a_payment_that_is_not_a_payment
    refused("База приняла отрицательную плату.") { insert("consignments", **bill(company_id: @gnr.id, pence: -1)) }
    refused("База приняла плату в ноль пенсов.") { insert("consignments", **bill(company_id: @gnr.id, pence: 0, reference: "B-Z")) }
  end

  def test_base_refuses_a_weight_that_is_not_a_weight
    refused("База приняла нулевой вес.") { insert("consignments", **bill(company_id: @gnr.id, weight_lb: 0, reference: "B-W")) }
  end

  def test_base_refuses_a_leg_of_no_length
    record = shipment
    refused("База приняла участок нулевой длины: по такому нечего делить.") do
      insert("legs", **leg_row(record, miles: 0))
    end
  end

  def test_a_proper_row_still_goes_in
    record = shipment
    assert insert("legs", **leg_row(record)),
           "Условие — это не запрет на всё подряд: годные строки обязаны ложиться."
    assert_equal 1, count("legs")
  end

  def test_the_conditions_are_named
    names = (check_constraints("consignments") + check_constraints("legs")).map { |item| item.name.to_s }
    assert_operator names.length, :>=, 4,
                    "Условий должно быть четыре: плата, вес, мили и набор ролей."
    nameless = names.select { |name| name.empty? || name.start_with?("chk_rails_") }
    assert_empty nameless,
                 "Условию нужно имя. Безымянному Rails придумает своё — chk_rails_8f3a2c, — и " \
                 "именно оно окажется в сообщении об отказе, которое прочтёт дежурный в три " \
                 "часа ночи. Искать по нему нечего."
  end

  # ─── прежнее цело ───────────────────────────────────────────────────────

  def test_the_model_still_complains_first
    refute Consignment.new(**bill(company_id: @gnr.id, pence: -1)).valid?,
           "Валидация из s04e03 никуда не делась: она объясняет, условие отказывает."
  end

  def test_earlier_rules_still_hold
    refute_nil index_on("companies", "code")
    refute_nil foreign_key("legs", "companies")
    assert_equal :date, column("consignments", "sent_on").type
  end

  # ─── схема ──────────────────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_rollback_removes_what_this_episode_added
    with, without = on_scratch do |context|
      context.migrate(version_of("AddConditionsToTheLedger"))
      had = scratch_columns("legs")
      context.down(version_before("AddConditionsToTheLedger"))
      [had, scratch_columns("legs")]
    end
    assert_includes with, "role"
    refute_includes without, "role", "Откат на одну ступень не снял столбец роли."
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments", "legs"
  end
end
