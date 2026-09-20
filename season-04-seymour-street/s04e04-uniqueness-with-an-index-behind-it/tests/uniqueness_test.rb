# CRIMSON RAILS — s04e04, проверка.
#
# Здесь впервые видно, чем валидация отличается от ограничения не на словах.
# Одна и та же проверка задаётся дважды: модели — и она отвечает «занято», —
# и базе, мимо модели, и она отказывает. Вторая проверка — та, которая
# считается.

require_relative "../../support/check.rb"

class UniquenessTest < Crimson::Test
  def setup
    wipe!("consignments", "companies")
  end

  # ─── индекс есть ────────────────────────────────────────────────────────

  def test_company_code_has_a_unique_index
    index = index_on("companies", "code")
    refute_nil index, "Индекса по code нет. Уникальность без индекса — это намерение."
    assert index.unique, "Индекс по code есть, но не уникальный: он ускоряет и ничего не держит."
  end

  def test_reference_has_a_unique_index
    index = index_on("consignments", "reference")
    refute_nil index, "Индекса по reference нет."
    assert index.unique, "Индекс по reference не уникальный."
  end

  # ─── база отказывает ────────────────────────────────────────────────────

  def test_base_refuses_a_second_road_with_the_same_code
    insert("companies", name: "Мидлендская дорога", code: "MID")
    assert_raises(ActiveRecord::RecordNotUnique,
                  "База приняла второй MID. Значит за правилом ничего не стоит, и в день, " \
                  "когда два запроса придут одновременно, в реестре окажутся две дороги.") do
      insert("companies", name: "Другая дорога", code: "MID")
    end
  end

  def test_base_refuses_a_second_bill_with_the_same_number
    insert("consignments", **bill)
    assert_raises(ActiveRecord::RecordNotUnique,
                  "База приняла второй бланк B-0992. Пост, не получивший квитанцию, пришлёт " \
                  "бланк снова — и Палата возьмёт плату дважды.") do
      insert("consignments", **bill)
    end
  end

  def test_different_codes_still_go_in
    insert("companies", name: "Мидлендская дорога", code: "MID")
    assert insert("companies", name: "Мидлендская дорога", code: "MDL"),
           "MID и MDL — разные коды. Уникальность кода не запрещает двух записей об одной " \
           "дороге: это другое правило, и его в реестре нет."
    assert_equal 2, count("companies")
  end

  # ─── модель объясняет ───────────────────────────────────────────────────

  def test_model_says_taken_before_the_base_does
    Company.create!(name: "Великая северная", code: "GNR")
    twin = Company.new(name: "Другая дорога", code: "GNR")
    refute twin.valid?, "Модель должна сказать «занято» до записи."
    refute_empty twin.errors[:code], "И сказать это про конкретное поле."
  end

  def test_model_says_taken_for_a_bill_too
    Consignment.create!(**bill)
    refute Consignment.new(**bill).valid?
    refute_empty Consignment.new(**bill).tap(&:valid?).errors[:reference]
  end

  def test_uniqueness_works_on_top_of_normalisation
    Company.create!(name: "Великая северная", code: "GNR")
    refute Company.new(name: "Другая", code: "  gnr  ").valid?,
           "Приведение к общему виду — часть уникальности: «gnr», « GNR » и «Gnr» это один код, " \
           "и «занято» отвечается на все написания сразу."
  end

  # ─── и то, ради чего сезон написан ──────────────────────────────────────

  def test_the_index_catches_what_the_validation_misses
    Company.create!(name: "Великая северная", code: "GNR")
    twin = Company.new(name: "Другая дорога", code: "GNR")

    assert_raises(ActiveRecord::RecordNotUnique,
                  "Валидация уникальности делает SELECT и спрашивает «занято?». Между её " \
                  "вопросом и записью проходит время, и за это время второй запрос успевает " \
                  "лечь. Проверка обходит валидацию ровно так, как это делает гонка, — и " \
                  "тогда отказать может только индекс.") do
      twin.save(validate: false)
    end
  end

  def test_the_race_leaves_one_record
    Company.create!(name: "Великая северная", code: "GNR")
    begin
      Company.new(name: "Другая дорога", code: "GNR").save(validate: false)
    rescue ActiveRecord::RecordNotUnique
      nil
    end
    assert_equal 1, count("companies"), "После отказа в реестре должна остаться одна запись."
  end

  # ─── завести или найти ──────────────────────────────────────────────────

  def test_find_or_create_by_does_not_double
    2.times { Company.find_or_create_by(code: "LNW") { |c| c.name = "Лондонская и северо-западная" } }
    assert_equal 1, count("companies"),
                 "`find_or_create_by` ищет, и если не нашёл — заводит. Дважды подряд он даёт " \
                 "одну запись."
  end

  def test_register_is_safe_to_call_twice
    first = Company.register(code: "LNW", name: "Лондонская и северо-западная")
    again = Company.register(code: "LNW", name: "Другая")
    assert first.persisted?
    assert_equal first.id, again.id,
                 "Второй вызов должен вернуть ту же запись, а не завести вторую и не упасть."
    assert_equal 1, count("companies")
  end

  def test_register_finds_what_came_past_the_model
    id = insert("companies", name: "Лондонская и северо-западная", code: "LNW")
    found = Company.register(code: "  lnw  ", name: "Другая")
    assert_equal id, found.id,
                 "Строку положили мимо модели — `register` обязан её найти, а не пытаться " \
                 "завести вторую. Приведение к общему виду работает и в поиске."
    assert_equal 1, count("companies")
  end

  def test_register_survives_the_index_refusal
    # Валидация видит занятый код почти всегда. «Почти» — это гонка: в ней
    # проверка не успевает, и отказывает индекс. Здесь эта гонка
    # воспроизводится честно — снятой валидацией: то же самое, что «не успела».
    Company.create!(name: "Лондонская и северо-западная", code: "LNW")

    racing = Class.new(Company) { clear_validators! }
    found = racing.register(code: "LNW", name: "Другая")

    assert found.persisted?
    assert_equal "Лондонская и северо-западная", found.name,
                 "`register` обязан пережить оба отказа одинаково: и жалобу валидации, и " \
                 "отказ индекса. В гонке приходит второй."
    assert_equal 1, count("companies")
  end

  def test_register_does_not_look_before_it_leaps
    asked = queries("companies") { Company.register(code: "GER", name: "Большая восточная") }
    assert_equal 1, asked.length,
                 "Запросов к реестру оказалось #{asked.length}. Порядок «сначала посмотреть, " \
                 "потом завести» лишний: посмотреть всё равно недостаточно — между ответом и " \
                 "записью второй запрос успевает лечь. Пробуют завести и разбираются с отказом."
    assert_equal 1, count("companies")
  end

  # ─── схема ──────────────────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_previous_ledgers_are_intact
    assert table?("companies")
    assert table?("consignments")
    assert_equal :integer, column("consignments", "pence").type
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments"
  end

  def test_rollback_removes_the_indexes_this_episode_added
    with, without = on_scratch do |context|
      context.migrate(version_of("AddUniqueIndexes"))
      had = scratch_indexes("companies").map(&:columns)
      context.down(version_before("AddUniqueIndexes"))
      [had, scratch_indexes("companies").map(&:columns)]
    end

    assert_includes with, %w[code]
    refute_includes without, %w[code],
                    "Откат на одну ступень не снял индекс. Так бывает, когда вместо `change` " \
                    "написан `up` без `down`: Rails молча ничего не делает, и схема после " \
                    "отката отличается от той, из которой откатывали."
  end
end
