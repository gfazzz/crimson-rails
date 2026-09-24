# CRIMSON RAILS — s04e10, проверка.
#
# Финал сезона. Проверяется не схема как таковая, а то, чего в схеме не видно:
# доедет ли набор миграций до конца на таблице, в которой уже лежат данные, и
# в каком виде он её оставит.
#
# Поэтому здесь появляется приём, которого не было девять серий: миграции
# прогоняются **не целиком**. База в памяти доводится до той ступени, где
# архив уже есть, в него засевается грязь — пять тысяч четыреста строк, как в
# жизни, — и только после этого прогоняются оставшиеся шаги.

require_relative "../../support/check.rb"

class LiveMigrationTest < Crimson::Test
  SHEETS = 1800            # маршрутных листов в архиве
  LEGS   = SHEETS * 2      # участков в них: по два на лист
  TWINS  = SHEETS          # вторых строк на тот же участок
  FORGED = "Колвик-Сайдингс"
  KEY    = "H."

  def setup
    wipe!("entries", "settlements", "legs", "consignments", "companies")
  end

  # ─── архив ──────────────────────────────────────────────────────────────

  def test_entries_exist_with_exactly_these_columns
    assert table?("entries"), "Таблицы entries нет: архив Палаты переносить некуда."
    assert_equal %w[clerk company_code created_at docket id miles position station
                    updated_at voided_at],
                 columns_after("EnforceOneLiveDocket", "entries"),
                 "Состав столбцов не тот: номер бланка, номер участка, код дороги, станция, " \
                 "мили, ключ ввода, отметка о погашении и две даты."
  end

  def test_the_archive_keeps_the_road_as_written
    assert_equal :string, column("entries", "company_code").type
    assert_nil foreign_key("entries", "companies"),
               "Внешний ключ на реестр дорог. Тогда строка шестьдесят девятого года ляжет " \
               "только если та дорога есть в реестре сегодня, — а половина из них с тех пор " \
               "слилась или исчезла. Архив хранит написанное, а не существующее."
  end

  def test_the_station_may_be_empty
    assert column("entries", "station").null,
           "Станция обязательна. В листах шестидесятых её не писали, и обязательной её " \
           "делает не Палата, а перенос, который на этих строках встанет."
  end

  def test_the_void_mark_came_later_and_is_optional
    mark = column("entries", "voided_at")
    assert_equal :datetime, mark.type
    assert mark.null,
           "Отметка о погашении обязательна. На таблице, где уже лежат строки, " \
           "`null: false` без умолчания не пройдёт: у существующих строк значения нет."
    refute_includes columns_after("CreateEntries", "entries"), "voided_at",
                    "Отметка появилась вместе с таблицей. Смысл серии в том, что столбец " \
                    "добавляют к ведомости, которая уже живёт, — и добавляют отдельным шагом."
  end

  def test_the_first_index_is_not_unique
    indexes = on_scratch do |context|
      context.migrate(version_of("CreateEntries"))
      scratch_indexes("entries").map { |index| [index.columns, index.unique] }
    end
    pair = indexes.select { |columns, _| columns == %w[docket position] }
    refute_empty pair, "По паре «бланк + участок» нет индекса. Повторы ищут по ней."
    assert_equal [false], pair.map(&:last).uniq,
                 "Уникальный индекс поставлен сразу, вместе с таблицей. На грязных данных он " \
                 "не ляжет — и перенос встанет на первой же паре."
  end

  def test_the_live_leg_index_is_unique_and_partial
    index = db.indexes("entries").find { |item| item.columns == %w[docket position] && item.unique }
    refute_nil index, "Нет уникального индекса по паре «бланк + участок»."
    refute_nil index.where,
               "Индекс уникален по всей таблице. Тогда погашенная строка занимает пару " \
               "навсегда, и архив нельзя ни пополнить, ни исправить. Уникальность нужна " \
               "только на живой части."
  end

  # ─── что говорит база, а не модель ──────────────────────────────────────

  def test_a_second_live_leg_is_refused_by_the_base
    insert("entries", **entry)
    assert_raises(ActiveRecord::RecordNotUnique,
                  "Вторая живая строка на тот же участок легла. Значит, разобрав архив один " \
                  "раз, Палата получит его грязным снова.") do
      insert("entries", **entry(company_code: "MDL", station: FORGED))
    end
  end

  def test_a_leg_whose_twin_is_voided_lays
    insert("entries", **entry(voided_at: "1891-09-04 11:00:00"))
    insert("entries", **entry(miles: 44))
    assert_equal 2, count("entries"),
                 "Погашенная строка не пускает новую с той же парой. Уникальность обязана " \
                 "считать только живые."
  end

  def test_two_voided_rows_on_one_leg_lay
    insert("entries", **entry(voided_at: "1891-09-04 11:00:00"))
    insert("entries", **entry(voided_at: "1891-09-04 11:00:01", miles: 44))
    assert_equal 2, count("entries"), "Погашенных строк на один участок бывает сколько угодно."
  end

  # ─── свойства самих шагов ───────────────────────────────────────────────

  def test_the_data_step_runs_outside_one_transaction
    assert step("VoidDuplicateDockets").disable_ddl_transaction,
           "Шаг с данными идёт одной проводкой. На пяти тысячах строк это заметно, на " \
           "миллионе — это час, в который в ведомость нельзя писать."
  end

  def test_the_schema_steps_keep_their_transaction
    %w[CreateEntries AddVoidedAtToEntries].each do |name|
      refute step(name).disable_ddl_transaction,
             "У шага #{name} снята проводка. Снимают её там, где она мешает, — а шаг со " \
             "схемой, упавший посередине без проводки, оставляет половину схемы."
    end
  end

  def test_the_data_step_does_not_touch_the_schema
    assert_equal measure(:columns_before), measure(:columns_after),
                 "Шаг с данными поменял схему. Шаги разделены ровно затем, чтобы дорогой " \
                 "проход по строкам можно было перезапустить, не трогая схему."
  end

  # ─── живой архив ────────────────────────────────────────────────────────

  def test_the_index_lays_on_a_dirty_archive
    assert measure(:indexed),
           "Уникального индекса на живом архиве нет. Значит, шаг с данными не разобрал " \
           "повторы — или разобрал не все."
  end

  def test_one_live_row_per_leg
    assert_equal 0, measure(:live_duplicates),
                 "В живой части остались пары «бланк + участок», встречающиеся дважды."
    assert_equal LEGS, measure(:live),
                 "Живых строк не столько, сколько участков. На каждый участок живая строка одна."
  end

  def test_the_archive_is_not_shortened
    assert_equal LEGS + TWINS, measure(:total),
                 "Из архива удалены строки. Из архива не вычёркивают: погашенная строка — " \
                 "это то, что было написано, и однажды именно она понадобится."
    assert_equal TWINS, measure(:voided_by_one_key),
                 "Погашенные строки перестали быть читаемыми. Отметка убирает строку из " \
                 "работы, а не из книги: по ней по-прежнему можно спросить, кто и что внёс."
  end

  def test_the_earliest_entry_survives
    assert_equal 0, measure(:not_earliest),
                 "Живой осталась не самая ранняя строка. Правило Палаты — «первая запись», и " \
                 "оно не про красоту: поздние записи и есть приписанные."
  end

  def test_a_leg_entered_once_is_untouched
    assert_equal SHEETS, measure(:untouched_singles),
                 "Погашены строки, у которых нет пары. Шаг обязан трогать только повторы."
  end

  def test_the_work_goes_in_batches
    writes = measure(:writes)
    assert_operator writes, :>=, 2,
                    "Все строки погашены одним запросом. На живой ведомости такой запрос " \
                    "держит всю таблицу до конца — а идёт он не секунду. Проход делают " \
                    "порциями."
    assert_operator writes, :<=, 100,
                    "Запросов на запись #{writes} — это строка за строкой. Порция в несколько " \
                    "сотен строк стоит одного запроса; строка за строкой стоит стольких, " \
                    "сколько строк."
  end

  # ─── перезапуск ─────────────────────────────────────────────────────────

  def test_a_half_done_run_finishes_correctly
    result = dirty_run(voided_ahead: 500)
    assert result[:indexed], "Индекс не лёг после перезапуска."
    assert_equal 0, result[:live_duplicates],
                 "Шаг, прерванный посередине, при повторном запуске не доделал работу. " \
                 "Проводки у него нет — значит, перезапуск обязателен, и отбор надо считать " \
                 "заново на каждом заходе, а не один раз в начале."
    assert_equal 0, result[:not_earliest],
                 "После перезапуска живой оказалась не самая ранняя строка."
    assert_equal TWINS, result[:voided],
                 "Уже погашенные строки погашены второй раз или сняты. Повторный проход по " \
                 "сделанному обязан быть пустым."
  end

  def test_running_the_data_step_twice_changes_nothing
    result = dirty_run(twice: true)
    assert_equal TWINS, result[:voided],
                 "Второй прогон шага изменил архив. Шаг без проводки запускают повторно " \
                 "всегда — после обрыва, после отката выкатки, просто чтобы убедиться."
    assert_equal LEGS, result[:live]
  end

  # ─── прежнее цело ───────────────────────────────────────────────────────

  def test_the_ledger_of_the_season_is_intact
    %w[companies consignments legs settlements].each do |name|
      assert table?(name), "Таблицы #{name} нет."
    end
    assert index_on("settlements", "company_id", "period").unique
    refute_nil db.indexes("legs").find { |index| index.unique && index.where }
  end

  def test_a_consignment_still_lays_and_a_twin_still_does_not
    insert("consignments", **bill)
    assert_raises(ActiveRecord::RecordNotUnique) { insert("consignments", **bill(pence: 1)) }
  end

  def test_schema_knows_every_migration
    assert_equal migration_versions.max, schema_version
  end

  def test_migrations_go_down_and_up_again
    assert_reversible "companies", "consignments", "legs", "settlements", "entries"
  end

  private

  def entry(**over)
    { docket: "R-0001", position: 2, company_code: "NER", station: nil,
      miles: 108, clerk: "W." }.merge(over)
  end

  # Ступень набора миграций по имени класса: у неё и спрашивают про проводку.
  def step(name)
    found = ActiveRecord::MigrationContext.new(Crimson.migration_paths)
                                          .migrations.find { |item| item.name == name }
    flunk "Миграции #{name} в db/migrate нет." if found.nil?
    found
  end

  # Один прогон на грязном архиве, общий для всех проверок, которым нужен
  # только его итог. Упавший прогон не роняет случайную проверку трассировкой,
  # а объясняется словами в той, которая за него отвечает.
  def measure(key)
    @@once ||= begin
      dirty_run
    rescue StandardError => error
      error
    end
    if @@once.is_a?(StandardError)
      flunk <<~TEXT
        Миграции не прошли на архиве, в котором уже лежат строки:

            #{@@once.class}: #{@@once.message.lines.first.to_s.strip}

        Так выглядит уникальный индекс, поставленный до того, как разобраны
        повторы. На пустой базе он ляжет, на живой — нет, и узнают об этом в
        день выкатки.
      TEXT
    end
    @@once.fetch(key)
  end

  # Довести базу в памяти до ступени, на которой архив уже есть, засеять его
  # грязью и прогнать оставшиеся шаги.
  def dirty_run(voided_ahead: 0, twice: false)
    on_scratch do |context|
      context.migrate(version_of("AddVoidedAtToEntries"))
      connection = ActiveRecord::Base.lease_connection
      seed(connection, voided_ahead: voided_ahead)

      result = { columns_before: scratch_columns("entries") }
      result[:writes] = queries("entries", kind: "UPDATE") { context.migrate }.length
      context.migrations.find { |item| item.name == "VoidDuplicateDockets" }.migrate(:up) if twice

      result.merge(readings(connection))
    end
  end

  def readings(connection)
    ask = ->(sql) { connection.select_value(sql).to_i }
    {
      columns_after: scratch_columns("entries"),
      indexed: scratch_indexes("entries").any? do |index|
        index.unique && index.columns == %w[docket position]
      end,
      total: ask.call("SELECT COUNT(*) FROM entries"),
      live: ask.call("SELECT COUNT(*) FROM entries WHERE voided_at IS NULL"),
      voided: ask.call("SELECT COUNT(*) FROM entries WHERE voided_at IS NOT NULL"),
      voided_by_one_key: ask.call(
        "SELECT COUNT(*) FROM entries WHERE voided_at IS NOT NULL AND clerk = '#{KEY}'"
      ),
      live_duplicates: ask.call(
        "SELECT COUNT(*) FROM (SELECT docket FROM entries WHERE voided_at IS NULL " \
        "GROUP BY docket, position HAVING COUNT(*) > 1)"
      ),
      not_earliest: ask.call(
        "SELECT COUNT(*) FROM entries e WHERE e.voided_at IS NULL AND e.id <> " \
        "(SELECT MIN(id) FROM entries x WHERE x.docket = e.docket AND x.position = e.position)"
      ),
      untouched_singles: ask.call(
        "SELECT COUNT(*) FROM entries WHERE voided_at IS NULL AND position = 1"
      )
    }
  end

  # Архив, перенесённый с бумаги как есть.
  #
  # Тысяча восемьсот листов, по два участка в каждом. У второго участка две
  # строки: как в листе и приписанная — с другой дорогой и станцией поверх.
  # Все приписанные помечены одним ключом ввода; в жизни это и оказывается
  # первым, что видно.
  def seed(connection, voided_ahead: 0)
    stamp = "1891-09-04 09:00:00"
    rows = []
    SHEETS.times do |number|
      docket = "R-#{format('%05d', number)}"
      rows << [docket, 1, "GNR", nil, 12, "W."]
      rows << [docket, 2, "NER", nil, 108, "W."]
      rows << [docket, 2, "MDL", FORGED, 108, KEY]
    end

    rows.each_slice(500) do |slice|
      values = slice.map do |row|
        "(#{row.map { |cell| connection.quote(cell) }.join(',')},'#{stamp}','#{stamp}')"
      end
      connection.execute(
        "INSERT INTO entries (docket, position, company_code, station, miles, clerk, " \
        "created_at, updated_at) VALUES #{values.join(',')}"
      )
    end

    return if voided_ahead.zero?

    # Прошлый запуск успел погасить часть повторов и оборвался. Гасятся именно
    # поздние строки — те же, что погасил бы целый проход.
    connection.execute(<<~SQL)
      UPDATE entries SET voided_at = '#{stamp}' WHERE id IN (
        SELECT id FROM entries e WHERE e.id <> (
          SELECT MIN(id) FROM entries x WHERE x.docket = e.docket AND x.position = e.position
        ) LIMIT #{voided_ahead}
      )
    SQL
  end
end
