# frozen_string_literal: true
#
# CRIMSON RAILS — s01e03, проверка.
# Свойства, а не текст.

require "minitest/autorun"

ART = File.expand_path("../artifacts/ledger.rb", __dir__)
SOL = File.expand_path("../solution/ledger.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ROADS = %w[NTK KSN HYG SJI].freeze
CARGO = %w[уголь рис шёлк лес чай].freeze

def build_entries(count, seed: 20260914)
  rng = Random.new(seed)
  Array.new(count) do |i|
    { road: ROADS[i % ROADS.size], cargo: CARGO[i % CARGO.size],
      weight: rng.rand(50..4000), charge: rng.rand(0..900) }
  end
end

def ledger(count = 37) = Abacus::Ledger.new(build_entries(count))

class TestEnumerable < Minitest::Test
  def test_ведомость_объявлена_перечислимой
    assert_includes Abacus::Ledger.ancestors, Enumerable,
                    "Ведомость должна подключать Enumerable: include Enumerable в теле класса."
    assert_kind_of Enumerable, ledger
  end

  def test_обход_называется_each
    assert_respond_to ledger, :each,
                      "Enumerable строит сорок методов поверх метода с именем each. " \
                      "Никакое другое имя ему не подходит."
  end

  def test_имя_из_первой_серии_продолжает_работать
    l = ledger(5)
    seen = []
    result = l.each_entry { |entry| seen << entry }
    assert_equal 5, seen.size,
                 "each_entry из s01e01 должен работать: договор, опубликованный наружу, не ломают."
    assert_same l, result, "И по-прежнему возвращать саму ведомость."
  end

  def test_each_без_блока_перечислитель
    assert_kind_of Enumerator, ledger.each
  end
end

class TestFreeMethods < Minitest::Test
  def setup
    @entries = build_entries(37)
    @ledger = Abacus::Ledger.new(@entries)
  end

  def test_map_select_find_пришли_сами
    assert_equal @entries.map { |e| e[:charge] }, @ledger.map { |e| e[:charge] }
    assert_equal @entries.select { |e| e[:road] == "SJI" }, @ledger.select { |e| e[:road] == "SJI" }
    assert_equal @entries.find { |e| e[:weight] > 3000 }, @ledger.find { |e| e[:weight] > 3000 }
  end

  def test_сортировки_и_края_пришли_сами
    assert_equal @entries.sort_by { |e| e[:charge] }, @ledger.sort_by { |e| e[:charge] }
    assert_equal @entries.max_by { |e| e[:weight] }, @ledger.max_by { |e| e[:weight] }
    assert_equal @entries.min_by { |e| e[:weight] }, @ledger.min_by { |e| e[:weight] }
    assert_equal @entries.first, @ledger.first
    assert_equal @entries.take(3), @ledger.take(3)
  end

  def test_select_возвращает_массив_а_не_ведомость
    result = @ledger.select { |e| e[:road] == "SJI" }
    assert_kind_of Array, result,
                   "Enumerable не знает, как собрать твой класс обратно, и отдаёт массив. " \
                   "Это не недочёт, это граница модуля — в s01e08 разберём, что с этим делают."
    refute_kind_of Abacus::Ledger, result
  end

  def test_each_slice_на_неполном_последнем_куске
    slices = @ledger.each_slice(8).to_a
    assert_equal 5, slices.size, "37 записей по 8 — это пять кусков."
    assert_equal 5, slices.last.size, "Последний кусок неполный, и это нормально."
    assert_equal @entries, slices.flatten(1), "Ни одна запись не потерялась."
  end

  def test_ленивый_обход_не_перебирает_всё
    yielded = 0
    counting = Class.new(Abacus::Ledger) do
      define_method(:each) do |&block|
        return enum_for(:each) unless block

        @entries.each { |entry| yielded += 1; block.call(entry) }
        self
      end
    end
    # yielded замкнут на локальную переменную теста — приём из s01e02

    result = counting.new(build_entries(1000)).lazy.map { |e| e[:charge] }.first(3)
    assert_equal 3, result.size, "lazy.first(3) должен вернуть три значения."
    assert_operator yielded, :<, 1000,
                    "Ленивый обход не должен перебирать всю ведомость ради трёх записей. " \
                    "Он работает, только если each сделан как положено: с yield по одной записи."
  end
end

class TestRewritten < Minitest::Test
  def setup
    @entries = build_entries(60)
    @ledger = Abacus::Ledger.new(@entries)
  end

  def test_total_by_и_count_where_на_месте
    assert_equal @entries.sum { |e| e[:charge] }, @ledger.total_by { |e| e[:charge] }
    assert_equal @entries.count { |e| e[:weight] > 2000 }, @ledger.count_where { |e| e[:weight] > 2000 }
  end

  def test_total_by_построен_на_обходе_а_не_на_своём_цикле
    passes = 0
    counting = Class.new(Abacus::Ledger) do
      define_method(:each) do |&block|
        return enum_for(:each) unless block

        passes += 1
        @entries.each { |entry| block.call(entry) }
        self
      end
    end

    counting.new(build_entries(10)).total_by { |e| e[:charge] }
    assert_equal 1, passes,
                 "total_by должен пройти по ведомости ровно один раз, через each."
  end

  def test_без_блока_по_прежнему_ArgumentError
    assert_raises(ArgumentError) { ledger.total_by }
    assert_raises(ArgumentError) { ledger.count_where }
    assert_raises(ArgumentError) { ledger.top_by(3) }
  end

  def test_правила_из_второй_серии_не_сломались
    l = ledger(20)
    rate = 2
    l.add_rule(:scaled) { |e| e[:charge] * rate }
    before = l.apply(:scaled)
    rate = 3
    assert_equal before / 2 * 3, l.apply(:scaled)
    l.register(:weight, ->(e) { e[:weight] })
    assert_equal l.total_by { |e| e[:weight] }, l.apply(:weight)
  end
end

class TestNewMethods < Minitest::Test
  def setup
    @entries = build_entries(37)
    @ledger = Abacus::Ledger.new(@entries)
  end

  def test_top_by_отдаёт_n_самых_крупных
    top = @ledger.top_by(4) { |e| e[:charge] }
    expected = @entries.max_by(4) { |e| e[:charge] }
    assert_equal expected, top
    assert_equal 4, top.size
  end

  def test_top_by_не_падает_когда_записей_меньше_чем_просят
    small = Abacus::Ledger.new(build_entries(2))
    assert_equal 2, small.top_by(10) { |e| e[:charge] }.size,
                 "Просят больше, чем есть, — отдаём сколько есть."
  end

  def test_by_road_группирует_по_дорогам
    grouped = @ledger.by_road
    assert_kind_of Hash, grouped
    assert_equal @entries.group_by { |e| e[:road] }, grouped
    assert_equal @entries.size, grouped.values.sum(&:size), "Ни одна запись не потерялась."
  end

  def test_by_road_не_выбрасывает_дорогу_с_одной_записью
    entries = build_entries(6) + [{ road: "TKY", cargo: "чай", weight: 10, charge: 5 }]
    grouped = Abacus::Ledger.new(entries).by_road

    assert_includes grouped.keys, "TKY",
                    "Дорога с единственной перевозкой — такая же дорога. " \
                    "group_by не фильтрует, и by_road не должен."
    assert_equal 1, grouped["TKY"].size
    assert_equal entries.size, grouped.values.sum(&:size), "Ни одна запись не потерялась."
  end
end
