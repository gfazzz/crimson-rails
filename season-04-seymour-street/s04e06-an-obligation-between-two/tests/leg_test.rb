# CRIMSON RAILS — s04e06, проверка.
#
# Связь «многие ко многим» с собственными графами — это не связь, а ведомость.
# Проверяется она как ведомость: что пара уникальна, что ссылки ведут на
# существующее и что цепочка `through` читает то, что нужно.

require_relative "../../support/check.rb"

class LegTest < Crimson::Test
  def setup
    wipe!("legs", "consignments", "companies")
  end

  def road(code, name = "Дорога #{code}")
    Company.create!(code: code, name: name)
  end

  def shipment(company, reference: "B-1041")
    Consignment.create!(**bill(company_id: company.id, reference: reference))
  end

  # ─── форма ведомости участков ───────────────────────────────────────────

  def test_legs_exist_with_exactly_these_columns
    assert table?("legs"), "Таблицы legs нет. Участок пути — третья ведомость Палаты."
    assert_equal %w[company_id consignment_id created_at id miles position updated_at],
                 columns_after("CreateLegs", "legs"),
                 "Состав столбцов не тот: перевозка, дорога, порядковый номер участка и мили."
  end

  def test_both_links_are_required_and_indexed
    %w[consignment_id company_id].each do |name|
      refute column("legs", name).null, "Столбец #{name} объявлен необязательным."
      refute_nil index_on("legs", name) || index_on("legs", name, "position"),
                 "По #{name} нет индекса."
    end
    refute_nil index_on("legs", "company_id"),
               "Индекса по дороге нет: «все участки этой дороги» будут читать всю ведомость."
  end

  def test_both_foreign_keys_exist
    refute_nil foreign_key("legs", "consignments"), "Нет внешнего ключа на перевозки."
    refute_nil foreign_key("legs", "companies"), "Нет внешнего ключа на реестр дорог."
  end

  def test_miles_and_position_are_whole_numbers
    assert_equal :integer, column("legs", "miles").type
    assert_equal :integer, column("legs", "position").type
    refute column("legs", "miles").null
    refute column("legs", "position").null
  end

  # ─── пара уникальна ─────────────────────────────────────────────────────

  def test_the_unique_index_is_on_the_pair_and_in_this_order
    index = index_on("legs", "consignment_id", "position")
    refute_nil index,
               "Нет составного индекса по паре «перевозка + позиция». Порядок столбцов важен: " \
               "участки всегда ищут внутри перевозки, а не позицию саму по себе."
    assert index.unique, "Составной индекс есть, но не уникальный."
  end

  def test_base_refuses_a_second_leg_in_the_same_place
    company = road("GNR")
    record = shipment(company)
    insert("legs", consignment_id: record.id, company_id: company.id, position: 1, miles: 40)
    assert_raises(ActiveRecord::RecordNotUnique,
                  "На одной перевозке два первых участка. Значит порядок пути перестал быть " \
                  "порядком, и делить выручку по нему нельзя.") do
      insert("legs", consignment_id: record.id, company_id: company.id, position: 1, miles: 12)
    end
  end

  def test_the_same_position_in_another_consignment_is_fine
    company = road("GNR")
    one = shipment(company, reference: "B-1")
    two = shipment(company, reference: "B-2")
    insert("legs", consignment_id: one.id, company_id: company.id, position: 1, miles: 40)
    assert insert("legs", consignment_id: two.id, company_id: company.id, position: 1, miles: 40),
           "Уникальна пара, а не позиция: первых участков в ведомости столько же, сколько " \
           "перевозок."
  end

  def test_model_says_taken_for_a_position_within_the_consignment
    company = road("GNR")
    record = shipment(company)
    Leg.create!(consignment: record, company: company, position: 1, miles: 40)
    twin = Leg.new(consignment: record, company: company, position: 1, miles: 12)
    refute twin.valid?
    refute_empty twin.errors[:position]
  end

  # ─── ссылки ведут на существующее ───────────────────────────────────────

  def test_base_refuses_a_leg_of_a_consignment_that_does_not_exist
    company = road("GNR")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      insert("legs", consignment_id: 999_999, company_id: company.id, position: 1, miles: 40)
    end
  end

  def test_base_refuses_a_leg_of_a_road_that_does_not_exist
    company = road("GNR")
    record = shipment(company)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      insert("legs", consignment_id: record.id, company_id: 999_999, position: 1, miles: 40)
    end
  end

  # ─── цепочка ────────────────────────────────────────────────────────────

  def test_consignment_reads_its_legs_in_order
    first = road("GNR")
    second = road("NER")
    record = shipment(first)
    Leg.create!(consignment: record, company: second, position: 2, miles: 31)
    Leg.create!(consignment: record, company: first, position: 1, miles: 40)

    assert_equal [1, 2], record.reload.legs.map(&:position),
                 "Участки читаются по порядку пути, а не по порядку заведения."
    assert_equal [40, 31], record.legs.map(&:miles)
  end

  def test_consignment_reads_the_roads_through_the_legs
    first = road("GNR")
    second = road("NER")
    record = shipment(first)
    Leg.create!(consignment: record, company: first, position: 1, miles: 40)
    Leg.create!(consignment: record, company: second, position: 2, miles: 31)

    assert_equal %w[GNR NER], record.reload.companies.order(:code).pluck(:code),
                 "`has_many through:` читает связь по цепочке, а не заводит вторую."
  end

  def test_road_reads_the_consignments_it_carried
    first = road("GNR")
    second = road("NER")
    one = shipment(first, reference: "B-1")
    two = shipment(first, reference: "B-2")
    Leg.create!(consignment: one, company: second, position: 1, miles: 40)
    Leg.create!(consignment: two, company: second, position: 1, miles: 12)

    assert_equal %w[B-1 B-2], second.carried_consignments.order(:reference).pluck(:reference),
                 "Обратная сторона той же цепочки: перевозки, в которых дорога участвовала."
    assert_equal 0, first.carried_consignments.count,
                 "Отправитель — не участник пути: это разные связи, и путать их нельзя."
  end

  # ─── что чего стоит при удалении ────────────────────────────────────────

  def test_removing_a_consignment_takes_its_legs
    company = road("GNR")
    record = shipment(company)
    Leg.create!(consignment: record, company: company, position: 1, miles: 40)

    assert record.destroy, "Перевозку убрать можно."
    assert_equal 0, count("legs"),
                 "Участок без своей перевозки не значит ничего — здесь `:destroy` верен."
  end

  def test_removing_a_road_with_legs_is_refused
    first = road("GNR")
    second = road("NER")
    record = shipment(first)
    Leg.create!(consignment: record, company: second, position: 1, miles: 40)

    refute second.destroy, "Дорогу, по которой шли участки, убрать нельзя: по ним делят выручку."
    refute_empty second.errors[:base]
    assert Company.exists?(second.id)
  end

  def test_base_refuses_to_remove_a_road_with_legs
    first = road("GNR")
    second = road("NER")
    record = shipment(first)
    insert("legs", consignment_id: record.id, company_id: second.id, position: 1, miles: 40)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      db.execute("DELETE FROM companies WHERE id = #{second.id}")
    end
  end

  # ─── правила участка ────────────────────────────────────────────────────

  def test_miles_and_position_must_be_positive
    company = road("GNR")
    record = shipment(company)
    refute Leg.new(consignment: record, company: company, position: 0, miles: 40).valid?
    refute Leg.new(consignment: record, company: company, position: 1, miles: 0).valid?
    refute Leg.new(consignment: record, company: company, position: 1, miles: -3).valid?
    assert Leg.new(consignment: record, company: company, position: 1, miles: 1).valid?
  end

  # ─── схема ──────────────────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments", "legs"
  end
end
