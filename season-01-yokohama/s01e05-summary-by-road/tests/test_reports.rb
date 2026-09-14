# frozen_string_literal: true
#
# CRIMSON RAILS — s01e05, проверка.

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

def build_entries(count, seed: 20260917)
  rng = Random.new(seed)
  Array.new(count) do |i|
    { road: ROADS[i % ROADS.size], cargo: CARGO[i % CARGO.size],
      weight: rng.rand(50..4000), charge: rng.rand(0..900) }
  end
end

def report(entries) = Abacus::Report.new(Abacus::Ledger.new(entries))

# Ведомость, которая считает, сколько раз её обошли.
def counting_report(entries)
  passes = [0]
  klass = Class.new(Abacus::Ledger) do
    define_method(:each) do |&block|
      return enum_for(:each) unless block

      passes[0] += 1
      @entries.each { |entry| block.call(entry) }
      self
    end
  end
  [Abacus::Report.new(klass.new(entries)), passes]
end

class TestChargesByRoad < Minitest::Test
  def test_сумма_по_каждой_дороге
    entries = build_entries(52)
    expected = entries.group_by { |e| e[:road] }
                      .transform_values { |rows| rows.sum { |e| e[:charge] } }
    assert_equal expected, report(entries).charges_by_road
  end

  def test_дорога_с_одной_перевозкой_остаётся
    entries = build_entries(4) + [{ road: "TKY", cargo: "чай", weight: 10, charge: 7 }]
    assert_equal 7, report(entries).charges_by_road["TKY"]
  end

  def test_на_пустой_ведомости_пустой_свод
    assert_equal({}, report([]).charges_by_road)
  end
end

class TestCargoCounts < Minitest::Test
  def test_считает_вхождения
    entries = build_entries(40)
    assert_equal entries.map { |e| e[:cargo] }.tally, report(entries).cargo_counts
  end

  def test_груз_встретившийся_однажды_попадает_в_свод
    entries = [
      { road: "NTK", cargo: "чай", weight: 1, charge: 1 },
      { road: "NTK", cargo: "чай", weight: 1, charge: 1 },
      { road: "KSN", cargo: "шёлк", weight: 1, charge: 1 }
    ]
    assert_equal({ "чай" => 2, "шёлк" => 1 }, report(entries).cargo_counts)
  end

  def test_на_пустой_ведомости_пустой_хеш
    assert_equal({}, report([]).cargo_counts)
  end
end

class TestSummaryByRoad < Minitest::Test
  def test_три_итога_по_каждой_дороге
    entries = build_entries(48)
    result = report(entries).summary_by_road

    entries.group_by { |e| e[:road] }.each do |road, rows|
      assert_equal rows.size, result[road][:count], "Число перевозок по #{road}."
      assert_equal rows.sum { |e| e[:weight] }, result[road][:weight], "Вес по #{road}."
      assert_equal rows.sum { |e| e[:charge] }, result[road][:charge], "Плата по #{road}."
    end
  end

  def test_за_один_обход_а_не_за_три
    rep, passes = counting_report(build_entries(24))
    rep.summary_by_road
    assert_equal 1, passes[0],
                 "Обходов вышло #{passes[0]}. Три итога собираются за один проход: " \
                 "накопитель несут через обход, а не группируют трижды."
  end

  def test_на_пустой_ведомости_пустой_свод
    assert_equal({}, report([]).summary_by_road)
  end

  def test_итоги_свода_сходятся_с_общими
    entries = build_entries(30)
    rep = report(entries)
    total = rep.summary_by_road.values.sum { |row| row[:charge] }
    assert_equal rep.total_charge, total, "Свод по дорогам обязан сойтись с общим итогом."
  end
end

class TestMismatch < Minitest::Test
  def test_всё_сошлось_значит_пусто
    entries = build_entries(20)
    rep = report(entries)
    assert_equal({}, rep.mismatch(rep.charges_by_road),
                 "Когда расхождений нет, в ответе не должно быть ничего — " \
                 "в том числе нулей.")
  end

  def test_показывает_только_разошедшиеся_дороги
    entries = build_entries(20)
    rep = report(entries)
    reported = rep.charges_by_road.dup
    reported["SJI"] -= 40

    result = rep.mismatch(reported)
    assert_equal({ "SJI" => 40 }, result,
                 "Наш итог больше присланного на 40 — значит, +40 по SJI, " \
                 "и ни одной другой дороги в ответе быть не должно.")
  end

  def test_знак_расхождения_не_потерян
    entries = build_entries(20)
    rep = report(entries)
    reported = rep.charges_by_road.dup
    reported["NTK"] += 15
    assert_equal({ "NTK" => -15 }, rep.mismatch(reported),
                 "Наш итог меньше присланного — расхождение отрицательное.")
  end

  def test_дорога_которой_нет_у_нас_это_тоже_расхождение
    entries = build_entries(8)
    rep = report(entries)
    reported = rep.charges_by_road.merge("TKY" => 500)
    assert_equal({ "TKY" => -500 }, rep.mismatch(reported),
                 "Дорога прислала итог, а в нашей ведомости её нет. " \
                 "Это расхождение, а не повод пропустить дорогу.")
  end

  def test_дорога_которой_нет_у_них_это_тоже_расхождение
    entries = build_entries(8) + [{ road: "TKY", cargo: "чай", weight: 10, charge: 60 }]
    rep = report(entries)
    reported = rep.charges_by_road.reject { |road, _| road == "TKY" }
    assert_equal({ "TKY" => 60 }, rep.mismatch(reported))
  end
end
