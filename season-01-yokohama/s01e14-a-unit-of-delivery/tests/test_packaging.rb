# frozen_string_literal: true
#
# CRIMSON RAILS — s01e14, проверка.
#
# Здесь проверяется не поведение классов — они уже проверены в своих сериях, —
# а упаковка: находит ли гем свои файлы, откуда берётся версия и что написано
# в паспорте.

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "rubygems"

SERIES = File.expand_path("..", __dir__)
SUPPORT = File.join(SERIES, "support", "lib", "abacus")

def artifact(name)
  own = File.join(SERIES, "artifacts", name)
  return own if File.exist?(own) && ENV["FORCE_SOLUTION"].nil?

  File.join(SERIES, "solution", name)
end

ENTRY_POINT = artifact("abacus.rb")
GEMSPEC     = artifact("abacus.gemspec")
puts "Источник: #{File.dirname(ENTRY_POINT).sub(File.expand_path("..", SERIES) + "/", "")}/"
unless File.exist?(File.join(SERIES, "artifacts", "abacus.rb"))
  puts "(артефакта нет — проверяю эталон)"
end

# Раскладка настоящего гема: lib/abacus.rb + lib/abacus/*.rb + abacus.gemspec
GEM_ROOT = Dir.mktmpdir("abacus-gem")
FileUtils.mkdir_p(File.join(GEM_ROOT, "lib"))
FileUtils.cp_r(SUPPORT, File.join(GEM_ROOT, "lib", "abacus"))
FileUtils.cp(ENTRY_POINT, File.join(GEM_ROOT, "lib", "abacus.rb"))
FileUtils.cp(GEMSPEC, File.join(GEM_ROOT, "abacus.gemspec"))
FileUtils.touch(File.join(GEM_ROOT, "README.md"))
FileUtils.touch(File.join(GEM_ROOT, "LICENSE"))
Minitest.after_run { FileUtils.remove_entry(GEM_ROOT) }

$LOAD_PATH.unshift(File.join(GEM_ROOT, "lib"))
REQUIRE_RESULT = require "abacus"

class TestEntryPoint < Minitest::Test
  def test_одного_require_достаточно
    assert REQUIRE_RESULT, "require \"abacus\" должен пройти успешно."
    %w[Ledger Report Tariff Keys Entry Convertible Registry Loader Finder Macros].each do |name|
      assert Abacus.const_defined?(name), "Abacus::#{name} не подтянулся точкой входа."
    end
  end

  def test_повторный_require_безопасен
    assert_equal false, require("abacus"),
                 "Второй require того же файла обязан вернуть false, а не " \
                 "загрузить всё заново. Это делает сам Ruby — но только если " \
                 "файл подключают через require, а не читают вручную"
  end

  def test_версия_есть_и_осмысленна
    assert Abacus.const_defined?(:VERSION), "Гем без версии не собрать."
    assert_match(/\A\d+\.\d+\.\d+\z/, Abacus::VERSION,
                 "Версия — три числа через точку: major.minor.patch")
    assert_predicate Abacus::VERSION, :frozen?
  end

  def test_ничего_не_протекло_в_глобальное_пространство
    %i[Ledger Report Tariff Entry Registry Finder Macros Keys].each do |name|
      refute Object.const_defined?(name, false),
             "::#{name} определён вне модуля Abacus. Гем занимает ровно одно " \
             "имя верхнего уровня — своё."
    end
  end

  def test_библиотека_действительно_работает
    ledger = Abacus::Ledger.new([{ road: "SJI", cargo: "чай", weight: 800, charge: 40 }])
    assert_equal 40, ledger.total_by { |entry| entry[:charge] }
    assert_equal 1, Abacus::Finder.new(ledger.to_a).count_by_road("SJI")
  end
end

class TestLoadPath < Minitest::Test
  # Точка входа кладётся ОТДЕЛЬНО от папки abacus/. require найдёт файлы
  # через $LOAD_PATH; require_relative будет искать рядом с собой и не найдёт.
  def test_файлы_ищутся_через_load_path_а_не_относительно_точки_входа
    Dir.mktmpdir("abacus-split") do |root|
      entry_dir = File.join(root, "entry")
      lib_dir = File.join(root, "lib")
      FileUtils.mkdir_p(entry_dir)
      FileUtils.mkdir_p(lib_dir)
      FileUtils.cp_r(SUPPORT, File.join(lib_dir, "abacus"))
      FileUtils.cp(ENTRY_POINT, File.join(entry_dir, "abacus.rb"))

      ok = system(RbConfig.ruby, "-I#{entry_dir}", "-I#{lib_dir}",
                  "-e", 'require "abacus"; exit(Abacus.const_defined?(:Ledger) ? 0 : 1)',
                  out: File::NULL, err: File::NULL)

      assert ok,
             "Точка входа должна подключать файлы через require, а не " \
             "require_relative: гем находит свои файлы по $LOAD_PATH, и в " \
             "установленном геме они лежат не там, где при разработке."
    end
  end
end

class TestGemspec < Minitest::Test
  def setup
    @spec = Dir.chdir(GEM_ROOT) { Gem::Specification.load("abacus.gemspec") }
    refute_nil @spec, "Паспорт гема не читается: Gem::Specification.load вернул nil"
  end

  def test_имя_и_версия
    assert_equal "abacus", @spec.name
    assert_equal Abacus::VERSION, @spec.version.to_s,
                 "Версия в паспорте должна браться из библиотеки, а не " \
                 "вписываться второй раз: две записи разойдутся"
  end

  def test_лицензия_и_описание
    assert_equal "MIT", @spec.license, "Курс и его гем — MIT"
    refute_empty @spec.summary.to_s, "Без краткого описания гем не примут"
    refute_match(/TODO|FIXME|Write a short summary/i, @spec.summary.to_s,
                 "Описание должно быть написано, а не оставлено заготовкой")
    refute_empty @spec.authors.reject { |a| a.to_s.empty? }
  end

  def test_требование_к_версии_ruby
    assert @spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.3.0")),
           "Курс заявлен на Ruby 3.3+."
    refute @spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.2.0")),
           "И не ниже: требование должно быть указано, а не оставлено пустым; 3.2 уже без поддержки."
  end

  def test_список_файлов_и_пути_загрузки
    assert_includes @spec.files, "lib/abacus.rb", "Точка входа обязана попасть в гем"
    assert_operator @spec.files.grep(%r{\Alib/abacus/.*\.rb\z}).size, :>=, 5,
                    "Файлы библиотеки тоже должны попасть в гем"
    assert_equal ["lib"], @spec.require_paths,
                 "require_paths говорит RubyGems, что добавить в $LOAD_PATH"
  end

  def test_паспорт_читается_там_где_нет_git
    refute File.exist?(File.join(GEM_ROOT, ".git")),
           "Проверка идёт во временной папке без репозитория."
    assert_operator @spec.files.size, :>, 0,
                    "Если список файлов пуст — вероятно, он собирается через " \
                    "`git ls-files`, а вне репозитория это даёт пустоту"
  end
end
