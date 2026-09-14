# frozen_string_literal: true
#
# CRIMSON RAILS — s01e01, проверка.
# Берём artifacts/ledger.rb; если его нет — solution/ledger.rb.
#
# Проверяются свойства, а не текст: тест ни разу не читает твой файл как
# строку. Он создаёт данные, вызывает поведение и смотрит на результат.
# Прочитать этот файл — законный ход: он и есть техническое задание.

require "minitest/autorun"

ART = File.expand_path("../artifacts/ledger.rb", __dir__)
SOL = File.expand_path("../solution/ledger.rb", __dir__)

source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ROADS  = %w[NTK KSN HYG SJI].freeze
CARGO  = %w[уголь рис шёлк лес чай].freeze

# Данные строятся с фиксированным зерном: два прогона подряд дают одно и то же.
def build_entries(count, seed: 20260914)
  rng = Random.new(seed)
  Array.new(count) do |i|
    { road: ROADS[i % ROADS.size],
      cargo: CARGO[i % CARGO.size],
      weight: rng.rand(50..4000),
      charge: rng.rand(0..900) }
  end
end

class TestEachEntry < Minitest::Test
  def test_вызывает_блок_ровно_столько_раз_сколько_записей
    [0, 1, 7, 113].each do |count|
      calls = 0
      Abacus::Ledger.new(build_entries(count)).each_entry { calls += 1 }
      assert_equal count, calls,
                   "На #{count} записях блок вызван #{calls} раз. " \
                   "yield должен сработать ровно один раз на запись."
    end
  end

  def test_отдаёт_записи_как_есть_и_в_том_же_порядке
    entries = build_entries(9)
    seen = []
    Abacus::Ledger.new(entries).each_entry { |entry| seen << entry }
    assert_equal entries, seen,
                 "Блок должен получать сами записи и в исходном порядке."
  end

  def test_возвращает_саму_ведомость_а_не_массив
    ledger = Abacus::Ledger.new(build_entries(5))
    result = ledger.each_entry { }
    assert_same ledger, result,
                "each_entry вернул #{result.class}. Должен вернуть саму ведомость (self): " \
                "Array#each возвращает получателя, и твой обход обязан вести себя так же."
  end

  def test_без_блока_возвращает_перечислитель_а_не_падает
    ledger = Abacus::Ledger.new(build_entries(4))
    result = begin
      ledger.each_entry
    rescue LocalJumpError
      flunk "each_entry без блока упал с LocalJumpError. Проверь block_given? и верни enum_for."
    end
    assert_kind_of Enumerator, result,
                   "Без блока each_entry вернул #{result.inspect}. Ожидается Enumerator."
    assert_equal 4, result.to_a.size,
                 "Перечислитель должен перебирать те же записи."
  end
end

class TestTotalBy < Minitest::Test
  def test_суммирует_то_что_вернул_блок
    entries = build_entries(50)
    expected = entries.map { |e| e[:charge] }.inject(0) { |acc, v| acc + v }
    actual = Abacus::Ledger.new(entries).total_by { |e| e[:charge] }
    assert_equal expected, actual,
                 "Сумма плат не сошлась. total_by складывает то, что вернул блок, " \
                 "а не что-нибудь из записи по своему выбору."
  end

  def test_блок_решает_что_суммировать
    entries = build_entries(30)
    by_weight = Abacus::Ledger.new(entries).total_by { |e| e[:weight] }
    expected  = entries.map { |e| e[:weight] }.inject(0) { |acc, v| acc + v }
    assert_equal expected, by_weight,
                 "Тот же метод с другим блоком должен дать другую сумму. " \
                 "Если сумма не изменилась — метод считает сам, а не спрашивает блок."
  end

  def test_на_пустой_ведомости_ноль_а_не_nil
    result = Abacus::Ledger.new([]).total_by { |e| e[:charge] }
    assert_equal 0, result,
                 "На пустой ведомости вернулось #{result.inspect}. Сумма ничего — это 0."
  end

  def test_без_блока_понятная_ошибка_а_не_LocalJumpError
    error = assert_raises(ArgumentError, StandardError) do
      Abacus::Ledger.new(build_entries(3)).total_by
    end
    refute_kind_of LocalJumpError, error,
                   "Без блока вылетел LocalJumpError. Он сообщает, что блока нет, " \
                   "но не говорит, какому методу он был нужен. Подними свой ArgumentError."
    assert_kind_of ArgumentError, error
  end

  def test_обходит_через_each_entry_а_не_своим_циклом
    counting = Class.new(Abacus::Ledger) do
      attr_reader :passes
      def each_entry(&block)
        @passes = (@passes || 0) + 1
        super(&block)
      end
    end

    ledger = counting.new(build_entries(6))
    ledger.total_by { |e| e[:charge] }
    assert_equal 1, ledger.passes.to_i,
                 "total_by не воспользовался each_entry (обходов: #{ledger.passes.inspect}). " \
                 "Обход в классе должен быть один: остальные методы строятся на нём."
  end
end

class TestCountWhere < Minitest::Test
  def test_считает_записи_на_которых_блок_истинен
    entries = build_entries(80)
    expected = entries.count { |e| e[:weight] > 2000 }
    actual = Abacus::Ledger.new(entries).count_where { |e| e[:weight] > 2000 }
    assert_equal expected, actual, "Счётчик не сошёлся."
    assert_operator expected, :>, 0, "Тест бессмысленен, если условию не отвечает ни одна запись."
  end

  def test_истина_по_рубистски_ноль_и_пустая_строка_истинны
    entries = [{ road: "NTK", cargo: "", weight: 0, charge: 0 }]
    ledger = Abacus::Ledger.new(entries)

    assert_equal 1, ledger.count_where { |e| e[:charge] },
                 "Ноль в Ruby истинен. Если запись не сосчиталась — внутри стоит " \
                 "сравнение с true вместо проверки на истинность."
    assert_equal 1, ledger.count_where { |e| e[:cargo] },
                 "Пустая строка в Ruby истинна."
    assert_equal 0, ledger.count_where { |_e| nil },
                 "nil ложен."
    assert_equal 0, ledger.count_where { |_e| false },
                 "false ложен."
  end

  def test_на_пустой_ведомости_ноль
    assert_equal 0, Abacus::Ledger.new([]).count_where { true }
  end

  def test_без_блока_понятная_ошибка
    assert_raises(ArgumentError) { Abacus::Ledger.new(build_entries(3)).count_where }
  end
end
