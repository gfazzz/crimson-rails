# CRIMSON RAILS — s04e03, проверка.
#
# Единственная серия сезона, где проверяется модель, а не схема, — и потому
# здесь же видно, чего модель не делает. Валидация называет поле и объясняет
# причину; базу она не защищает, и за каждой из них в s04e08 встанет
# ограничение.

require_relative "../../support/check.rb"

class RecordTest < Crimson::Test
  def setup
    wipe!("consignments", "companies")
  end

  def good = { reference: "b-1041", description: "чай, ящиков 12",
               sent_on: "1891-08-19", pence: 787, weight_lb: 336 }

  # ─── модель и таблица ───────────────────────────────────────────────────

  def test_models_are_wired_to_their_tables
    assert_equal "companies", Company.table_name,
                 "Модель Company должна отвечать за таблицу companies: Rails связывает их по " \
                 "соглашению об именах."
    assert_equal "consignments", Consignment.table_name
  end

  def test_new_does_not_touch_the_base
    Company.new(name: "Мидлендская дорога", code: "MID")
    assert_equal 0, count("companies"),
                 "`new` только собирает объект в памяти. В базу ходит `save`."
  end

  def test_created_record_is_persisted_and_has_an_id
    company = Company.create!(name: "Мидлендская дорога", code: "MID")
    assert company.persisted?, "После create! запись сохранена."
    refute company.new_record?
    assert company.id, "Номер назначает база, а не приложение."
    assert_equal 1, count("companies")
  end

  def test_timestamps_fill_themselves
    company = Company.create!(name: "Ланкаширская и Йоркширская", code: "LY")
    refute_nil company.created_at
    refute_nil company.updated_at
  end

  # ─── что говорит модель, когда ей не нравится ───────────────────────────

  def test_invalid_record_names_the_field
    company = Company.new(code: "MID")
    refute company.valid?, "Дорога без названия не годится."
    refute_empty company.errors[:name],
                 "Ошибка должна быть привязана к полю: читателю нужно знать, что именно " \
                 "исправлять. Этого база не умеет — она просто откажет."
  end

  def test_save_returns_false_and_writes_nothing
    company = Company.new(code: "MID")
    refute company.save, "`save` на негодной записи возвращает false."
    assert_equal 0, count("companies")
  end

  def test_save_bang_raises
    assert_raises(ActiveRecord::RecordInvalid,
                  "`save!` бросает. Это разные инструменты: `save` — когда есть кому показать " \
                  "ошибку, `save!` — когда её некому показать и падать правильнее.") do
      Company.new(code: "MID").save!
    end
  end

  def test_code_has_a_length_rule
    refute Company.new(name: "Дорога", code: "M").valid?, "Код в один знак — не код."
    refute Company.new(name: "Дорога", code: "MIDLAND").valid?
    assert Company.new(name: "Дорога", code: "MID").valid?
  end

  def test_model_refuses_before_the_base_does
    # Обязательность есть и в схеме, и в модели, и порядок важен: модель
    # обязана отказать первой. Иначе читатель вместо «укажите код» получает
    # падение базы, а приложение — пятисотую вместо формы с ошибкой.
    company = Company.new(name: "Дорога без кода")
    refute company.valid?
    refute_empty company.errors[:code]
    assert_equal false, company.save,
                 "`save` должен вернуть false, а не упасть с ошибкой базы."
  end

  # ─── приведение до проверки ─────────────────────────────────────────────

  def test_code_is_normalised_before_validation
    company = Company.create!(name: "Мидлендская дорога", code: "  mid  ")
    assert_equal "MID", company.code,
                 "Код приводится к общему виду до проверки: иначе пришлось бы проверять все " \
                 "написания сразу, а в реестре он один."
    assert_equal "MID", db.select_value("SELECT code FROM companies")
  end

  def test_reference_is_normalised_too
    record = Consignment.create!(**good)
    assert_equal "B-1041", record.reference,
                 "Номер бланка приводится к общему виду так же, как код дороги: в ведомости " \
                 "он один, а пишут его как придётся."
    assert_equal "B-1041", db.select_value("SELECT reference FROM consignments")
  end

  # ─── перевозка ──────────────────────────────────────────────────────────

  def test_consignment_requires_what_the_bill_requires
    %i[reference description sent_on].each do |field|
      record = Consignment.new(**good.except(field))
      refute record.valid?, "Перевозка без #{field} не годится."
      refute_empty record.errors[field]
    end
  end

  def test_payment_must_be_a_whole_positive_number
    refute Consignment.new(**good.merge(pence: nil)).valid?
    refute Consignment.new(**good.merge(pence: 0)).valid?, "Перевозка за ноль пенсов — не перевозка."
    refute Consignment.new(**good.merge(pence: -5)).valid?, "Плата не бывает отрицательной."
    refute Consignment.new(**good.merge(pence: 7.5)).valid?, "Пенс не делится."
    assert Consignment.new(**good).valid?
  end

  def test_weight_must_be_a_whole_positive_number
    refute Consignment.new(**good.merge(weight_lb: 0)).valid?
    refute Consignment.new(**good.merge(weight_lb: -1)).valid?
    assert Consignment.new(**good.merge(weight_lb: 1)).valid?
  end

  def test_settled_defaults_from_the_schema
    assert_equal false, Consignment.new.settled,
                 "Умолчание объявлено в схеме, и модель читает его оттуда. Дублировать его в " \
                 "коде значит завести второе место, где оно записано."
  end

  # ─── приведение типов ───────────────────────────────────────────────────

  def test_types_come_back_the_way_they_were_declared
    record = Consignment.create!(**good)
    found = Consignment.find(record.id)
    assert_kind_of Date, found.sent_on, "Дата объявлена датой — значит и приходит датой."
    assert_equal Date.new(1891, 8, 19), found.sent_on
    assert_kind_of Integer, found.pence
    assert_equal 787, found.pence
    assert_equal false, found.settled
  end

  # ─── что изменилось ─────────────────────────────────────────────────────

  def test_a_record_knows_what_changed_in_it
    company = Company.create!(name: "Мидлендская дорога", code: "MID")
    refute company.changed?, "Сразу после сохранения менять нечего."

    company.name = "Мидлендская железная дорога"
    assert company.changed?
    assert_includes company.changed, "name"
    assert_equal "Мидлендская дорога", company.name_was,
                 "Прежнее значение доступно до сохранения: на этом держатся колбэки и " \
                 "частичное обновление."

    company.save!
    refute company.changed?
    assert company.saved_change_to_name?
  end

  def test_update_and_update_bang_differ_the_same_way
    company = Company.create!(name: "Мидлендская дорога", code: "MID")
    refute company.update(name: ""), "`update` на негодных данных возвращает false."
    assert_equal "Мидлендская дорога", db.select_value("SELECT name FROM companies"),
                 "И ничего не пишет: в базе осталось прежнее."
    assert_raises(ActiveRecord::RecordInvalid) { company.update!(name: "") }
  end

  # ─── граница модели ─────────────────────────────────────────────────────

  def test_validation_is_not_a_guarantee
    # Ровно то, ради чего написан весь сезон: правило есть только в модели,
    # и любой, кто пришёл не через неё, о нём не знает.
    refute Company.new(name: "Дорога", code: "MIDLAND").valid?,
           "Модель длинный код не принимает."
    id = insert("companies", name: "Дорога", code: "MIDLAND")
    assert id, "А база — принимает: правила длины в схеме нет."
    assert_equal "MIDLAND", db.select_value("SELECT code FROM companies WHERE id = #{id}")
  end

  # ─── схема не менялась ──────────────────────────────────────────────────

  def test_no_new_migration_in_this_episode
    assert_equal migration_versions.max, schema_version
    assert table?("companies")
    assert table?("consignments")
  end
end
