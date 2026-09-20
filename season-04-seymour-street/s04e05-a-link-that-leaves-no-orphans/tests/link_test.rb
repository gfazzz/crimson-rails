# CRIMSON RAILS — s04e05, проверка.
#
# Связь живёт в двух местах: в модели — чтобы одно находилось по другому, и в
# схеме — чтобы ссылка вела на существующую строку. Проверяется, как обычно,
# второе: сырой SQL пытается положить перевозку с дороги, которой нет.

require_relative "../../support/check.rb"

class LinkTest < Crimson::Test
  def setup
    wipe!("consignments", "companies")
  end

  # ─── столбец и ключ ─────────────────────────────────────────────────────

  def test_consignment_has_a_sender_column
    assert_includes column_names("consignments"), "company_id",
                    "У перевозки нет отправителя. Бланк приносит дорога — без неё перевозки " \
                    "не бывает."
    assert_equal :integer, column("consignments", "company_id").type
  end

  def test_sender_is_required
    refute column("consignments", "company_id").null,
           "Отправитель объявлен необязательным."
    assert_raises(ActiveRecord::NotNullViolation) do
      insert("consignments", **bill.except(:company_id))
    end
  end

  def test_sender_is_indexed
    refute_nil index_on("consignments", "company_id"),
               "Индекса по отправителю нет. Без него «все перевозки этой дороги» читают всю " \
               "ведомость, а удаление дороги — тем более."
  end

  def test_foreign_key_exists_and_points_at_the_register
    key = foreign_key("consignments", "companies")
    refute_nil key, "Внешнего ключа нет. Тогда ссылка на дорогу — просто число."
    assert_equal "company_id", key.column
  end

  # ─── база не оставляет сирот ────────────────────────────────────────────

  def test_base_refuses_a_consignment_from_a_road_that_does_not_exist
    assert_raises(ActiveRecord::InvalidForeignKey,
                  "База приняла перевозку с дороги, которой нет в реестре. Это и есть сирота: " \
                  "запись, ссылающаяся в никуда, — и найти её потом можно только перебором.") do
      insert("consignments", **bill(company_id: 999_999))
    end
  end

  def test_base_refuses_to_remove_a_road_that_still_has_consignments
    id = a_company
    insert("consignments", **bill(company_id: id))
    assert_raises(ActiveRecord::InvalidForeignKey,
                  "Дорогу удалили вместе с её перевозками в ведомости. Внешний ключ должен " \
                  "этого не позволить — кто бы ни удалял.") do
      db.execute("DELETE FROM companies WHERE id = #{id}")
    end
  end

  def test_a_road_without_consignments_goes_away
    id = insert("companies", name: "Дорога без перевозок", code: "NON")
    db.execute("DELETE FROM companies WHERE id = #{id}")
    assert_equal 0, db.select_value("SELECT COUNT(*) FROM companies WHERE id = #{id}").to_i
  end

  # ─── связь в модели ─────────────────────────────────────────────────────

  def test_consignment_finds_its_road
    company = Company.create!(name: "Великая северная", code: "GNR")
    record = Consignment.create!(**bill(company_id: company.id))
    assert_equal company, record.reload.company,
                 "`belongs_to` — это способ найти дорогу по перевозке."
  end

  def test_road_finds_its_consignments
    company = Company.create!(name: "Великая северная", code: "GNR")
    Consignment.create!(**bill(company_id: company.id, reference: "B-1"))
    Consignment.create!(**bill(company_id: company.id, reference: "B-2"))
    assert_equal 2, company.consignments.count,
                 "`has_many` — обратная сторона той же связи."
    assert_equal %w[B-1 B-2], company.consignments.order(:reference).pluck(:reference)
  end

  def test_consignment_without_a_road_is_invalid
    record = Consignment.new(**bill.except(:company_id))
    refute record.valid?,
           "С Rails 5 `belongs_to` обязателен по умолчанию: объект без дороги негоден."
    refute_empty record.errors[:company]
  end

  # ─── удаление объясняется ───────────────────────────────────────────────

  def test_model_refuses_to_destroy_a_road_with_consignments
    company = Company.create!(name: "Великая северная", code: "GNR")
    Consignment.create!(**bill(company_id: company.id))

    refute company.destroy, "`destroy` должен вернуть false, а не бросить и не удалить."
    refute_empty company.errors[:base],
                 "И объяснить: `restrict_with_error` называет причину, а внешний ключ — нет."
    assert Company.exists?(company.id), "И дорога должна остаться в реестре."
  end

  def test_refused_destroy_leaves_the_consignments_alone
    company = Company.create!(name: "Великая северная", code: "GNR")
    Consignment.create!(**bill(company_id: company.id))
    company.destroy
    assert_equal 1, count("consignments"),
                 "Перевозки не удаляют вместе с дорогой: для ведомости Палаты это потеря денег, " \
                 "а не уборка. `dependent: :destroy` здесь был бы неверным решением."
  end

  def test_model_lets_an_empty_road_go
    company = Company.create!(name: "Дорога без перевозок", code: "NON")
    assert company.destroy
    assert_equal 0, count("companies")
  end

  # ─── прежнее цело ───────────────────────────────────────────────────────

  def test_previous_rules_still_hold
    Company.create!(name: "Великая северная", code: "GNR")
    refute Company.new(name: "Другая", code: "gnr").valid?, "Уникальность кода из s04e04."
    assert_equal :integer, column("consignments", "pence").type, "Плата из s04e02."
  end

  # ─── схема ──────────────────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_rollback_removes_the_sender
    with, without = on_scratch do |context|
      context.migrate(version_of("AddSenderToConsignments"))
      had = scratch_columns("consignments")
      context.down(version_before("AddSenderToConsignments"))
      [had, scratch_columns("consignments")]
    end
    assert_includes with, "company_id"
    refute_includes without, "company_id",
                    "Откат на одну ступень не снял столбец отправителя."
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments"
  end
end
