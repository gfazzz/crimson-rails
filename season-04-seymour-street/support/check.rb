# CRIMSON RAILS — общая библиотека проверок сезона 4.
#
# Здесь одна мысль, и она же контракт сезона: **проверяется база, а не
# модель.** Валидация в Active Record — это вежливая просьба к тому, кто
# пользуется приложением. Ограничение в схеме — это отказ базы принять строку,
# кем бы она ни была прислана: другим процессом, консолью, скриптом переноса,
# соседней системой, которая ходит в ту же базу мимо Rails.
#
# Поэтому почти всякая проверка здесь вставляет строку **сырым SQL**, минуя
# модель. Если после этого строка легла — значит за валидацией ничего не
# стоит, и в день, когда два запроса придут одновременно, ведомость разойдётся.
#
# Приложение сезона лежит рядом; путь к нему можно задать снаружи (LEDGER_APP),
# и на этом держится прогон эталона: он идёт на копии приложения и работу
# проходящего курс не трогает.

module Crimson
  SERVICE_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  class << self
    def app
      @app ||= File.expand_path(ENV.fetch("LEDGER_APP") { File.join(__dir__, "..", "app") })
    end

    # Поднять приложение сезона в тестовой среде и привести тестовую базу к
    # схеме. Схема — db/schema.rb — здесь единственный источник правды: это
    # файл, который Rails пишет сам по итогу миграций, и подделать его,
    # не прогнав миграцию, нельзя.
    def boot!
      return if @booted

      ENV["RAILS_ENV"] = "test"
      # Набор гемов берётся у приложения: проверка идёт в той же среде, в
      # которой приложение живёт, а не в соседней.
      ENV["BUNDLE_GEMFILE"] = File.join(app, "Gemfile")
      require "bundler/setup"
      require "minitest/autorun"
      require File.join(app, "config/environment")
      require "active_record/migration"

      begin
        ActiveRecord::Migration.maintain_test_schema!
      rescue ActiveRecord::PendingMigrationError
        abort <<~TEXT
          В db/migrate есть миграции, которых нет в схеме.
          Схема — это то, что база знает про себя; пока миграция не прогнана,
          она ничего не значит. Прогони:

              cd #{app} && bin/rails db:migrate
        TEXT
      end

      ActiveRecord::Migration.verbose = false
      @booted = true
    end

    def migration_paths = File.join(app, "db", "migrate")
  end
end

# Приложение поднимается один раз, при загрузке библиотеки: дальше проверки
# работают с уже поднятым Rails, а не поднимают его каждая заново.
Crimson.boot!

module Crimson
  # Общий предок проверок сезона.
  class Test < Minitest::Test
    def db = ActiveRecord::Base.lease_connection

    # ─── что знает про себя база ──────────────────────────────────────────

    def tables = db.tables.sort - SERVICE_TABLES

    def table?(name) = db.table_exists?(name.to_s)

    # Столбец схемы: тип, обязательность, значение по умолчанию.
    #
    # Отсутствие таблицы или столбца — это несделанная работа, а не поломка
    # проверки: сообщать о ней надо словами, а не трассировкой стека.
    def column(table, name)
      flunk missing(table) unless table?(table)
      found = db.columns(table.to_s).find { |item| item.name == name.to_s }
      flunk "В таблице #{table} нет столбца #{name}." if found.nil?
      found
    end

    def column_names(table)
      table?(table) ? db.columns(table.to_s).map(&:name) : []
    end

    # Индекс по перечисленным столбцам — именно по ним и именно в этом
    # порядке: порядок столбцов в составном индексе решает, какие запросы он
    # ускорит, и это не придирка.
    def index_on(table, *columns)
      wanted = columns.flatten.map(&:to_s)
      db.indexes(table.to_s).find { |index| index.columns == wanted }
    end

    def foreign_key(table, to_table)
      db.foreign_keys(table.to_s).find { |key| key.to_table == to_table.to_s }
    end

    def check_constraints(table)
      db.check_constraints(table.to_s)
    rescue NotImplementedError
      []
    end

    # ─── данные мимо модели ───────────────────────────────────────────────

    # Сырой INSERT: ни валидаций, ни колбэков, ни умолчаний Active Record.
    # Ровно то, чем в жизни оказывается «скрипт переноса» и «чиним руками
    # в консоли».
    def insert(table, **values)
      flunk missing(table) unless table?(table)
      values = stamps(table).merge(values)
      names = values.keys.map { |name| db.quote_column_name(name) }.join(", ")
      items = values.values.map { |value| db.quote(value) }.join(", ")
      db.insert("INSERT INTO #{db.quote_table_name(table)} (#{names}) VALUES (#{items})")
    end

    def count(table)
      flunk missing(table) unless table?(table)
      db.select_value("SELECT COUNT(*) FROM #{db.quote_table_name(table)}").to_i
    end

    def wipe!(*names)
      (names.empty? ? tables.reverse : names.flatten).each do |name|
        db.execute("DELETE FROM #{db.quote_table_name(name)}") if table?(name)
      end
    end

    # ─── обратимость ──────────────────────────────────────────────────────

    # Прокатить все миграции вниз и снова вверх — на отдельной базе в памяти,
    # чтобы не трогать ту, на которой идут остальные проверки.
    #
    # Это не педантизм: миграция, которую нельзя откатить, превращает любую
    # ошибку в схеме в ручную работу на живой базе. Возвращает состав таблиц
    # после каждого шага.
    def migrate_down_and_up
      on_scratch do |context|
        steps = {}
        context.migrate
        steps[:up] = scratch_tables
        context.down(0)
        steps[:down] = scratch_tables
        context.migrate
        steps[:again] = scratch_tables
        steps
      end
    end

    # Отдельная база в памяти и набор миграций проходящего курс. Всё, что
    # нужно, чтобы спросить у миграций то, чего не спросишь у схемы: обратимы
    # ли они и что было на предыдущей ступени.
    def on_scratch
      was = ActiveRecord::Base.connection_db_config
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      yield ActiveRecord::MigrationContext.new(Crimson.migration_paths)
    ensure
      ActiveRecord::Base.establish_connection(was)
    end

    def scratch_tables
      ActiveRecord::Base.lease_connection.tables.sort - SERVICE_TABLES
    end

    def scratch_columns(table)
      connection = ActiveRecord::Base.lease_connection
      connection.table_exists?(table.to_s) ? connection.columns(table.to_s).map(&:name).sort : nil
    end

    # Версии миграций по порядку — так, как их видит Rails, а не по именам
    # файлов.
    def migration_versions
      ActiveRecord::MigrationContext.new(Crimson.migration_paths).migrations.map(&:version)
    end

    # Версия, до которой доведена база. Её Rails хранит в самой базе, в
    # schema_migrations: схема — это не файл с описанием, а то, что база
    # про себя знает.
    def schema_version
      ActiveRecord::Base.connection_pool.migration_context.current_version
    end

    private

    # Отсутствующая таблица объясняется двумя способами, и второй встречается
    # чаще: заготовку миграции прогнали пустой, а заполнили потом. Версия при
    # этом уже записана как прогнанная, и Rails больше к файлу не вернётся —
    # ровно то, о чём эта серия.
    def missing(table)
      <<~TEXT
        Таблицы #{table} в схеме нет: её должна объявить миграция.
        Если миграция уже написана — её версия записана как прогнанная
        (так бывает, когда прогнали пустую заготовку, а заполнили после).
        Прогнать миграции заново, с нуля:

            cd #{Crimson.app} && bin/rails db:migrate:reset
      TEXT
    end

    def stamps(table)
      names = column_names(table)
      now = Time.current
      stamp = {}
      stamp[:created_at] = now if names.include?("created_at")
      stamp[:updated_at] = now if names.include?("updated_at")
      stamp
    end
  end
end
