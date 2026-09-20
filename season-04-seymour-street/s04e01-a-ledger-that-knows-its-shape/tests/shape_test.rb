# CRIMSON RAILS — s04e01, проверка.
#
# Проверяется не текст миграции, а то, что знает про себя база после неё.
# Почти каждая проверка ниже вставляет строку сырым SQL, мимо модели: так
# в жизни выглядит скрипт переноса, консоль и соседняя система. Если строка
# легла — значит объявления не было.

require_relative "../../support/check.rb"

class ShapeTest < Crimson::Test
  def setup
    wipe!("companies") if table?("companies")
  end

  # ─── форма ведомости ────────────────────────────────────────────────────

  def test_ledger_exists
    assert table?("companies"),
           "Таблицы companies нет. Реестр дорог — первая ведомость Палаты, с неё сезон и " \
           "начинается. Имя во множественном числе: так Rails связывает таблицу с моделью."
  end

  def test_ledger_has_exactly_what_was_declared
    assert_equal %w[code created_at id name registered_on updated_at], column_names("companies").sort,
                 "Состав столбцов не тот. В ведомости членов Палаты нужны название, код, дата " \
                 "вступления и две даты, которые Rails ведёт сам."
  end

  def test_only_one_ledger_so_far
    assert_equal %w[companies], tables,
                 "Сезон начинается с одной ведомости. Лишние таблицы — это или чужая миграция, " \
                 "или миграция, прогнанная дважды."
  end

  # ─── что объявлено обязательным ─────────────────────────────────────────

  def test_name_is_a_string
    assert_equal :string, column("companies", "name").type
  end

  def test_code_is_a_string
    assert_equal :string, column("companies", "code").type
  end

  def test_name_declared_required_in_the_schema
    refute column("companies", "name").null,
           "Столбец name объявлен необязательным. Дорога без названия — не запись реестра."
  end

  def test_code_declared_required_in_the_schema
    refute column("companies", "code").null,
           "Столбец code объявлен необязательным."
  end

  def test_base_refuses_a_road_without_a_name
    assert_raises(ActiveRecord::NotNullViolation,
                  "База приняла дорогу без названия. Значит обязательности нет — есть намерение.") do
      insert("companies", name: nil, code: "MID")
    end
  end

  def test_base_refuses_a_road_without_a_code
    assert_raises(ActiveRecord::NotNullViolation,
                  "База приняла дорогу без кода.") do
      insert("companies", name: "Мидлендская дорога", code: nil)
    end
  end

  def test_a_proper_road_goes_in
    id = insert("companies", name: "Мидлендская дорога", code: "MID", registered_on: "1842-01-02")
    assert id, "Правильная запись должна ложиться: объявление — это не запрет на всё подряд."
    assert_equal 1, count("companies")
  end

  # ─── дата вступления ────────────────────────────────────────────────────

  def test_registered_on_is_a_date
    assert_equal :date, column("companies", "registered_on").type,
                 "Дата вступления — это дата, а не строка и не время. Тип столбца — первое " \
                 "обещание, которое база даёт всем, кто в неё ходит."
  end

  def test_registered_on_may_be_unknown
    assert column("companies", "registered_on").null,
           "Дата вступления объявлена обязательной. У дорог, вступивших до 1860 года, её в " \
           "книге просто нет: обязательность, которой нельзя выполнить, заводить записи мешает."
    id = insert("companies", name: "Ланкаширская и Йоркширская", code: "LY")
    assert id
  end

  # ─── даты, которые ведёт Rails ──────────────────────────────────────────

  def test_timestamps_are_there_and_required
    %w[created_at updated_at].each do |name|
      assert_equal :datetime, column("companies", name).type, "#{name} — не datetime."
      refute column("companies", name).null, "#{name} объявлен необязательным."
    end
  end

  # ─── схема как факт ─────────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version,
                 "Схема отстаёт от миграций. db/schema.rb пишет Rails по итогу прогона; пока " \
                 "миграция не прогнана, она ничего не значит. Прогони bin/rails db:prepare."
  end

  def test_two_layers_not_one
    assert_equal 2, migration_versions.length,
                 "Миграций должно быть две. Столбец, понадобившийся после первой, добавляют " \
                 "второй — а не дописывают в первую."
  end

  def test_the_added_column_came_in_its_own_layer
    before, after = on_scratch do |context|
      versions = context.migrations.map(&:version).sort
      context.migrate(versions[-2])
      early = scratch_columns("companies")
      context.migrate
      [early, scratch_columns("companies")]
    end

    refute_nil before, "После первой миграции таблицы companies ещё нет."
    refute_includes before, "registered_on",
                    "Столбец registered_on появляется уже в первой миграции. Значит её " \
                    "дописали после прогона: у того, кто прогнал её раньше, этого столбца не " \
                    "будет никогда."
    assert_includes after, "registered_on"
  end

  # ─── обратимость ────────────────────────────────────────────────────────

  def test_migrations_go_down_and_up_again
    steps = migrate_down_and_up
    assert_equal %w[companies], steps[:up]
    assert_equal [], steps[:down],
                 "После отката таблица осталась. Миграция, которую нельзя откатить, превращает " \
                 "любую ошибку в схеме в ручную работу на живой базе."
    assert_equal %w[companies], steps[:again],
                 "Обратно вверх не поднялось. Откат обязан возвращать ровно то состояние, из " \
                 "которого откатывали."
  end
end
