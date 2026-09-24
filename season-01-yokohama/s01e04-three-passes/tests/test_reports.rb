# frozen_string_literal: true
#
# CRIMSON RAILS — s01e04, проверка.

require "minitest/autorun"
require_relative "../support/ledger"

ART = File.expand_path("../artifacts/reports.rb", __dir__)
SOL = File.expand_path("../solution/reports.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ROADS = %w[NTK KSN HYG SJI].freeze
CARGO = %w[уголь рис шёлк лес чай].freeze

def build_entries(count, seed: 20260916)
  rng = Random.new(seed)
  Array.new(count) do |i|
    { road: ROADS[i % ROADS.size], cargo: CARGO[i % CARGO.size],
      weight: rng.rand(50..4000), charge: rng.rand(0..900) }
  end
end

def report(entries) = Abacus::Report.new(Abacus::Ledger.new(entries))

class TestMap < Minitest::Test
  def setup
    @entries = build_entries(45)
    @report = report(@entries)
  end

  def test_charges_это_платы_в_порядке_ведомости
    assert_equal @entries.map { |e| e[:charge] }, @report.charges,
                 "Порядок должен совпадать с порядком ведомости"
  end

  def test_roads_без_повторов_и_в_порядке_появления
    assert_equal %w[NTK KSN HYG SJI], @report.roads,
                 "Дороги идут так, как встретились в ведомости. " \
                 "Отсортированный список выдаёт sort там, где его не просили"
  end

  def test_roads_на_пустой_ведомости_пустой_массив
    assert_equal [], report([]).roads
  end
end

class TestSelect < Minitest::Test
  def setup
    @entries = build_entries(60)
    @report = report(@entries)
  end

  def test_heavier_than_отбирает_строго_больше
    assert_equal @entries.select { |e| e[:weight] > 2000 }, @report.heavier_than(2000)
    edge = [{ road: "NTK", cargo: "чай", weight: 2000, charge: 1 }]
    assert_equal [], report(edge).heavier_than(2000),
                 "Ровно 2000 — не «тяжелее 2000». Границу считаем строго"
  end

  def test_lighter_than_это_дополнение_к_heavier_than
    heavy = @report.heavier_than(2000)
    light = @report.lighter_than(2000)
    assert_equal @entries.size, heavy.size + light.size,
                 "Вместе они должны давать всю ведомость и ничего не терять"
    assert_empty (heavy & light), "И не пересекаться"
  end

  def test_split_by_weight_отдаёт_обе_половины
    heavy, light = @report.split_by_weight(2000)
    assert_equal @report.heavier_than(2000), heavy
    assert_equal @report.lighter_than(2000), light
  end

  def test_split_by_weight_делает_один_обход_а_не_два
    passes = 0
    counting = Class.new(Abacus::Ledger) do
      define_method(:each) do |&block|
        return enum_for(:each) unless block

        passes += 1
        @entries.each { |entry| block.call(entry) }
        self
      end
    end

    Abacus::Report.new(counting.new(build_entries(20))).split_by_weight(2000)
    assert_equal 1, passes,
                 "Обходов вышло #{passes}. Оба ответа получают за один проход — " \
                 "в Enumerable для этого есть отдельный метод"
  end
end

class TestReduce < Minitest::Test
  def test_total_charge_складывает_платы
    entries = build_entries(70)
    assert_equal entries.sum { |e| e[:charge] }, report(entries).total_charge
  end

  def test_total_charge_на_пустой_ведомости_ноль_а_не_nil
    assert_equal 0, report([]).total_charge,
                 "reduce без начального значения на пустой коллекции возвращает nil. " \
                 "Сумма ничего — это ноль"
  end

  def test_longest_cargo_name
    entries = [
      { road: "NTK", cargo: "чай", weight: 1, charge: 1 },
      { road: "KSN", cargo: "каменный уголь", weight: 1, charge: 1 },
      { road: "HYG", cargo: "рис", weight: 1, charge: 1 }
    ]
    assert_equal "каменный уголь", report(entries).longest_cargo_name
  end

  def test_longest_cargo_name_первый_из_равных
    entries = [
      { road: "NTK", cargo: "рис", weight: 1, charge: 1 },
      { road: "KSN", cargo: "чай", weight: 1, charge: 1 }
    ]
    assert_equal "рис", report(entries).longest_cargo_name,
                 "При равной длине остаётся тот, что встретился первым: " \
                 "сравнение должно быть строгим, а не «больше или равно»"
  end

  def test_longest_cargo_name_на_пустой_ведомости_nil
    assert_nil report([]).longest_cargo_name
  end
end

class TestAverage < Minitest::Test
  def test_средняя_плата
    entries = build_entries(40)
    expected = entries.sum { |e| e[:charge] }.to_f / entries.size
    assert_in_delta expected, report(entries).average_charge, 1e-9
  end

  def test_средняя_не_целочисленная
    entries = [
      { road: "NTK", cargo: "чай", weight: 1, charge: 1 },
      { road: "KSN", cargo: "рис", weight: 1, charge: 2 }
    ]
    assert_in_delta 1.5, report(entries).average_charge, 1e-9,
                    "1 и 2 в среднем дают 1.5. Целочисленное деление даст 1 — " \
                    "и это молчаливая ошибка, которую никто не заметит"
  end

  def test_средняя_на_пустой_ведомости_nil_а_не_деление_на_ноль
    assert_nil report([]).average_charge,
               "Нет записей — нет средней. Ноль тут соврал бы: он значит " \
               "«перевозки были, и все бесплатные»"
  end
end
