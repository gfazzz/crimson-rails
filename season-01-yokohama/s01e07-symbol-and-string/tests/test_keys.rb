# frozen_string_literal: true
#
# CRIMSON RAILS — s01e07, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/keys.rb", __dir__)
SOL = File.expand_path("../solution/keys.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

JAPANESE = { "road" => "SJI", "cargo" => "чай", "weight" => 1200, "charge" => 340 }.freeze
BRITISH  = { road: "SJI", cargo: "чай", weight: 1200, charge: 340 }.freeze

class TestTheProblemItself < Minitest::Test
  def test_строка_и_символ_это_разные_ключи
    refute_equal JAPANESE, BRITISH,
                 "Эти два хеша выглядят одинаково и одинаковыми не являются. " \
                 "Вся серия про это"
    assert_equal 2, [JAPANESE, BRITISH].uniq.size,
                 "uniq тоже считает их разными — и потому дубликат не найдёт"
  end
end

class TestSymbolize < Minitest::Test
  def test_приводит_ключи_к_символам
    assert_equal BRITISH, Abacus::Keys.symbolize(JAPANESE)
  end

  def test_идемпотентно
    assert_equal BRITISH, Abacus::Keys.symbolize(BRITISH),
                 "Уже приведённый хеш не должен портиться при повторном приведении"
  end

  def test_не_трогает_значения
    result = Abacus::Keys.symbolize("cargo" => "чай")
    assert_equal "чай", result[:cargo],
                 "Значение осталось строкой: приводим ключи, а не всё подряд"
  end

  def test_рекурсивно_для_вложенных_хешей
    raw = { "road" => "SJI", "tariff" => { "base_rate" => 40, "rounding" => "up" } }
    expected = { road: "SJI", tariff: { base_rate: 40, rounding: "up" } }
    assert_equal expected, Abacus::Keys.symbolize(raw)
  end

  def test_рекурсивно_внутри_массивов
    raw = { "rows" => [{ "road" => "SJI" }, { "road" => "NTK" }] }
    expected = { rows: [{ road: "SJI" }, { road: "NTK" }] }
    assert_equal expected, Abacus::Keys.symbolize(raw)
  end

  def test_ключ_который_не_умеет_стать_символом_остаётся_как_есть
    raw = { 1 => "первая строка ведомости", "road" => "SJI" }
    result = Abacus::Keys.symbolize(raw)
    assert_equal "первая строка ведомости", result[1],
                 "Числовой ключ не превращают в символ — он остаётся числом"
    assert_equal "SJI", result[:road]
  end

  def test_не_меняет_исходный_хеш
    raw = { "road" => "SJI" }
    Abacus::Keys.symbolize(raw)
    assert_equal({ "road" => "SJI" }, raw,
                 "Приведение возвращает новый хеш и не портит переданный")
  end

  def test_не_хеш_возвращается_как_есть
    assert_equal 42, Abacus::Keys.symbolize(42)
    assert_nil Abacus::Keys.symbolize(nil)
  end
end

class TestStringify < Minitest::Test
  def test_приводит_ключи_к_строкам
    assert_equal JAPANESE, Abacus::Keys.stringify(BRITISH)
  end

  def test_круговое_свойство
    assert_equal BRITISH, Abacus::Keys.symbolize(Abacus::Keys.stringify(BRITISH)),
                 "Туда и обратно должно давать исходное"
  end

  def test_рекурсивно
    raw = { road: "SJI", tariff: { base_rate: 40 } }
    assert_equal({ "road" => "SJI", "tariff" => { "base_rate" => 40 } },
                 Abacus::Keys.stringify(raw))
  end
end

class TestSameRow < Minitest::Test
  def test_одна_перевозка_набранная_по_разному
    assert Abacus::Keys.same_row?(JAPANESE, BRITISH),
           "Одна и та же перевозка, записанная двумя конторами."
  end

  def test_разные_перевозки_остаются_разными
    other = BRITISH.merge(charge: 341)
    refute Abacus::Keys.same_row?(JAPANESE, other)
  end
end

class TestDedupe < Minitest::Test
  def test_убирает_двойника_различающегося_только_ключами
    rows = [JAPANESE, BRITISH]
    assert_equal 1, Abacus::Keys.dedupe(rows).size,
                 "Две записи об одной перевозке. Одна из них лишняя, " \
                 "и ровно она даёт расхождение в сорок сен"
  end

  def test_оставляет_первую_в_исходном_виде
    kept = Abacus::Keys.dedupe([JAPANESE, BRITISH]).first
    assert_equal JAPANESE, kept,
                 "Остаётся первая встретившаяся, и ключи ей не переписывают: " \
                 "как пришла из конторы, так и лежит"
  end

  def test_сохраняет_порядок_и_не_трогает_уникальные
    a = { road: "NTK", charge: 1 }
    b = { "road" => "KSN", "charge" => 2 }
    c = { road: "NTK", charge: 1 }
    assert_equal [a, b], Abacus::Keys.dedupe([a, b, c])
  end

  def test_пустой_список
    assert_equal [], Abacus::Keys.dedupe([])
  end

  def test_не_меняет_переданный_массив
    rows = [JAPANESE, BRITISH]
    Abacus::Keys.dedupe(rows)
    assert_equal 2, rows.size, "Исходный список остаётся как был"
  end
end
