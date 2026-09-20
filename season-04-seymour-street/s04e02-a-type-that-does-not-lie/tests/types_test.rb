# CRIMSON RAILS — s04e02, проверка.
#
# Проверяется, во что база превращает значение, прежде чем положить. Тип
# столбца — обещание всем, кто в неё ходит, и проверяется оно так же, как всё
# в этом сезоне: вставкой сырым SQL, мимо модели.

require_relative "../../support/check.rb"

class TypesTest < Crimson::Test
  def setup
    wipe!("consignments") if table?("consignments")
  end

  def good(**over)
    {
      reference: "B-1041", description: "чай, ящиков 12",
      sent_on: "1891-08-19", pence: 787, weight_lb: 336,
    }.merge(over)
  end

  # ─── форма ведомости перевозок ──────────────────────────────────────────

  def test_consignments_exist
    assert table?("consignments"),
           "Таблицы consignments нет. Перевозка — вторая ведомость Палаты после реестра дорог."
  end

  def test_columns_are_exactly_these
    assert_equal %w[created_at description id pence reference sent_on settled updated_at weight_lb],
                 column_names("consignments").sort,
                 "Состав столбцов не тот: номер бланка, груз, дата отправки, плата, вес, " \
                 "признак расчёта и две даты, которые Rails ведёт сам."
  end

  def test_first_ledger_is_intact
    assert table?("companies"), "Реестр дорог из первой серии никуда не делся."
  end

  # ─── то, над чем не считают, — строка ───────────────────────────────────

  def test_reference_is_a_required_string
    assert_equal :string, column("consignments", "reference").type,
                 "Номер бланка — строка: у него бывают буквы и ведущие нули, а складывать " \
                 "его никто не собирается."
    refute column("consignments", "reference").null
  end

  def test_description_is_a_required_string
    assert_equal :string, column("consignments", "description").type
    refute column("consignments", "description").null
  end

  # ─── день, а не момент ──────────────────────────────────────────────────

  def test_sent_on_is_a_date
    assert_equal :date, column("consignments", "sent_on").type,
                 "Дата отправки — `date`. `datetime` врал бы о точности, которой в бланке " \
                 "нет: там написано «19 августа», без часа."
  end

  def test_sent_on_is_required
    refute column("consignments", "sent_on").null
    assert_raises(ActiveRecord::NotNullViolation, "Перевозка без даты отправки — не перевозка.") do
      insert("consignments", **good(sent_on: nil))
    end
  end

  def test_date_comes_back_a_date
    insert("consignments", **good)
    value = db.select_value("SELECT sent_on FROM consignments")
    assert_equal "1891-08-19", value.to_s[0, 10],
                 "Дата вернулась не тем, чем легла. Так бывает, когда столбец объявлен строкой."
  end

  # ─── деньги целым числом ────────────────────────────────────────────────

  def test_pence_is_an_integer
    assert_equal :integer, column("consignments", "pence").type,
                 "Плата — целое число пенсов. `float` не умеет представить ни 0.1, ни 0.7, и " \
                 "сумма тысячи плат разойдётся с ручным счётом — всегда в одну сторону."
  end

  def test_pence_is_required
    refute column("consignments", "pence").null
    assert_raises(ActiveRecord::NotNullViolation) { insert("consignments", **good(pence: nil)) }
  end

  def test_a_thousand_payments_add_up_exactly
    1000.times { |i| insert("consignments", **good(reference: "B-#{i}", pence: 7)) }
    total = db.select_value("SELECT SUM(pence) FROM consignments")
    assert_kind_of Integer, total,
                   "Сумма вернулась дробным числом. Значит плата хранится не целым, и счёт " \
                   "Палаты расходится с ручным на доли пенса — ровно как в Йокогаме."
    assert_equal 7000, total
  end

  def test_weight_is_an_integer_with_its_unit_named
    assert_equal :integer, column("consignments", "weight_lb").type
    refute column("consignments", "weight_lb").null
    assert_includes column_names("consignments"), "weight_lb",
                    "Единица измерения стоит в имени столбца. Кан и фунты в одной ведомости " \
                    "стоили Палате сорока сен."
  end

  # ─── признак с умолчанием ───────────────────────────────────────────────

  def test_settled_is_a_boolean
    assert_equal :boolean, column("consignments", "settled").type
  end

  def test_settled_is_never_unknown
    refute column("consignments", "settled").null,
           "Признак расчёта объявлен необязательным. Тогда у него три состояния: да, нет и " \
           "NULL — «неизвестно», которого никто не объявлял."
  end

  def test_default_lives_in_the_base_not_in_the_model
    insert("consignments", **good)
    value = db.select_value("SELECT settled FROM consignments")
    refute [nil, "", "NULL"].include?(value),
           "Строка, пришедшая мимо модели, легла без ответа на вопрос «рассчитана ли». " \
           "Умолчание должно стоять в схеме: модель для того, кто пришёл через модель."
    assert_equal 0, value.to_i
  end

  # ─── время ──────────────────────────────────────────────────────────────

  def test_time_is_stored_in_utc
    assert_equal :utc, ActiveRecord.default_timezone,
                 "Время в базе хранится в UTC. Часовой пояс — свойство показа, а не хранения: " \
                 "иначе одна и та же запись меняет смысл при переезде сервера."
  end

  def test_timestamps_are_required_datetimes
    %w[created_at updated_at].each do |name|
      assert_equal :datetime, column("consignments", name).type
      refute column("consignments", name).null
    end
  end

  # ─── схема и обратимость ────────────────────────────────────────────────

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version,
                 "Схема отстаёт от миграций: прогони bin/rails db:migrate."
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments"
  end
end
