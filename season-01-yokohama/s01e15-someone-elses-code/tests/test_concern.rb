# frozen_string_literal: true
#
# CRIMSON RAILS — s01e15, финал сезона.
#
# Две части: своя примесь-с-зависимостями и приёмка всего, что построено
# за сезон. Новой темы здесь нет — только то, что уже было.

require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path("../support/lib", __dir__))
require "abacus"

ART = File.expand_path("../artifacts/concern.rb", __dir__)
SOL = File.expand_path("../solution/concern.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

# ——— часть первая: примесь —————————————————————————————————————

module Weighable
  extend Abacus::Concern

  included do
    @weighable_host = name || "аноним"
  end

  class_methods do
    def weighable_host = @weighable_host
    def unit_name = "килограмм"
  end

  def heavy? = weight > 2000
end

# Примесь, зависящая от другой примеси.
module Billable
  extend Abacus::Concern
  include Weighable

  class_methods do
    def billable? = true
  end

  def bill = heavy? ? charge * 2 : charge
end

class Shipment
  include Billable

  attr_reader :weight, :charge

  def initialize(weight, charge)
    @weight = weight
    @charge = charge
  end
end

class TestConcernBasics < Minitest::Test
  def test_методы_экземпляра_подмешались
    assert_predicate Shipment.new(2400, 10), :heavy?
    refute_predicate Shipment.new(800, 10), :heavy?
  end

  def test_ClassMethods_подключились_сами
    assert_equal "килограмм", Shipment.unit_name,
                 "Ради этого примесь и существует: в s01e09 для того же " \
                 "приходилось писать хук included с extend вручную"
    assert_predicate Shipment, :billable?
  end

  def test_блок_included_выполнился_в_классе_хозяине
    assert_equal "Shipment", Shipment.weighable_host,
                 "Блок included выполняется в контексте класса-хозяина: " \
                 "self в нём — Shipment, поэтому name даёт его имя"
  end

  def test_повторное_включение_не_выполняет_блок_снова
    runs = []
    mod = Module.new do
      extend Abacus::Concern
      included { runs << self }
    end

    host = Class.new { include mod }
    host.include(mod)
    host.include(mod)

    assert_equal 1, runs.size,
                 "Блок included выполнился #{runs.size} раза. Повторное " \
                 "включение в тот же класс не должно делать ничего: " \
                 "класс, уже включивший примесь, — это base < self"
    assert_equal [host], runs
  end
end

class TestDependencies < Minitest::Test
  def test_зависимость_включилась_в_класс_а_не_в_примесь
    assert_includes Shipment.ancestors, Weighable,
                    "Weighable должен оказаться в предках Shipment: примесь, " \
                    "включённая в примесь, разворачивается в класс-хозяин"
  end

  def test_порядок_предков_верный
    ancestors = Shipment.ancestors
    assert_operator ancestors.index(Billable), :<, ancestors.index(Weighable),
                    "Зависимость ставится дальше зависящего: Billable может " \
                    "перекрывать методы Weighable, а не наоборот"
  end

  def test_примесь_не_подмешала_зависимость_себе
    refute_includes Weighable.instance_methods(false), :bill
    refute_includes Billable.ancestors, Weighable,
                    "Weighable не должен включаться в сам Billable: он ждёт " \
                    "настоящего класса. Иначе ClassMethods подключились бы " \
                    "не туда"
  end

  def test_ClassMethods_обеих_примесей_на_месте
    assert_predicate Shipment, :billable?
    assert_equal "килограмм", Shipment.unit_name,
                 "Методы класса из зависимости тоже должны дойти до хозяина"
  end

  def test_методы_зависимости_работают_из_зависящего
    assert_equal 20, Shipment.new(2400, 10).bill, "heavy? пришёл из Weighable"
    assert_equal 10, Shipment.new(800, 10).bill
  end
end

class TestConcernErrors < Minitest::Test
  def test_второй_блок_included_это_ошибка
    assert_raises(Abacus::Concern::MultipleIncludedBlocks) do
      Module.new do
        extend Abacus::Concern
        included { 1 }
        included { 2 }
      end
    end
  end

  def test_class_methods_дважды_дополняет_тот_же_модуль
    mod = Module.new do
      extend Abacus::Concern
      class_methods { def first_one = :a }
      class_methods { def second_one = :b }
    end
    host = Class.new { include mod }

    assert_equal :a, host.first_one
    assert_equal :b, host.second_one, "Второй вызов не должен затирать первый"
  end

  def test_обычный_хук_included_с_аргументом_продолжает_работать
    seen = []
    mod = Module.new do
      extend Abacus::Concern
      define_singleton_method(:included) do |base|
        seen << base
        super(base)
      end
    end
    host = Class.new { include mod }

    assert_equal [host], seen,
                 "included с аргументом — обычный хук Ruby, и он обязан " \
                 "остаться рабочим"
  end
end

# ——— часть вторая: приёмка сезона ——————————————————————————————
#
# Ни одной новой темы. Каждая проверка — вклад одной серии.

class TestSeasonAcceptance < Minitest::Test
  ROWS = [
    { road: "SJI", cargo: "чай",   weight: 800,  charge: 40 },
    { road: "SJI", cargo: "уголь", weight: 2400, charge: 310 },
    { road: "NTK", cargo: "чай",   weight: 600,  charge: 95 },
    { road: "HYG", cargo: "рис",   weight: 1500, charge: 180 }
  ].freeze

  def setup
    @ledger = Abacus::Ledger.new(ROWS)
    @report = Abacus::Report.new(@ledger)
  end

  def test_s01e01_обход_и_счёт
    assert_equal 625, @ledger.total_by { |row| row[:charge] }
    assert_equal 2, @ledger.count_where { |row| row[:cargo] == "чай" }
  end

  def test_s01e02_правило_переживает_вызов
    rate = 2
    @ledger.add_rule(:doubled) { |row| row[:charge] * rate }
    assert_equal 1250, @ledger.apply(:doubled)
    rate = 3
    assert_equal 1875, @ledger.apply(:doubled)
  end

  def test_s01e03_ведомость_перечислима
    assert_includes Abacus::Ledger.ancestors, Enumerable
    assert_equal 2, @ledger.by_road["SJI"].size
  end

  def test_s01e04_отчёт
    assert_equal %w[SJI NTK HYG], @report.roads
    assert_equal 0, Abacus::Report.new(Abacus::Ledger.new([])).total_charge
  end

  def test_s01e05_свод_и_сверка
    assert_equal({ "SJI" => 350, "NTK" => 95, "HYG" => 180 }, @report.charges_by_road)
    assert_equal({ "SJI" => 40 }, @report.mismatch(@report.charges_by_road.merge("SJI" => 310)))
  end

  def test_s01e06_тариф
    tariff = Abacus::Tariff.from(base_rate: 40, minimum: 50, rounding: :nearest)
    assert_equal 320, tariff.charge_for(ROWS[0])
    assert_raises(ArgumentError) { Abacus::Tariff.from(base_rate: 40, mimimum: 50) }
  end

  def test_s01e07_ключи
    japanese = { "road" => "SJI", "cargo" => "чай", "weight" => 800, "charge" => 40 }
    assert Abacus::Keys.same_row?(japanese, ROWS[0])
    assert_equal 1, Abacus::Keys.dedupe([japanese, ROWS[0]]).size
  end

  def test_s01e08_запись_как_значение
    a = Abacus::Entry.from(ROWS[0])
    b = Abacus::Entry.from("road" => "SJI", "cargo" => "чай", "weight" => 800, "charge" => 40)
    assert_equal a, b
    assert_equal 1, [a, b].uniq.size
  end

  def test_s01e09_пересчёт_веса
    host = Class.new do
      include Abacus::Convertible
      attr_reader :weight, :unit
      def initialize(weight, unit) = (@weight, @unit = weight, unit)
    end
    assert_in_delta 798.75, host.new(213, :kan).weight_kg, 1e-9
  end

  def test_s01e10_реестр
    Abacus::Registry.reset!
    Abacus::Registry.configure { register("SJI", gauge: 1067, unit: :kan) }
    assert_equal({ gauge: 1067, unit: :kan }, Abacus::Registry["SJI"])
  ensure
    Abacus::Registry.reset!
  end

  def test_s01e11_ошибки
    source = Object.new
    def source.fetch = [{ cargo: "чай" }]
    def source.close = nil

    error = assert_raises(Abacus::MalformedRow) { Abacus::Loader.new(source).load }
    assert_equal 1, error.line
  end

  def test_s01e12_поиск_по_имени
    finder = Abacus::Finder.new(ROWS)
    assert_equal 2, finder.count_by_road("SJI")
    assert_equal 350, finder.total_by_road("SJI")
    assert_raises(NoMethodError) { finder.find_by_clerk("Ито") }
  end

  def test_s01e13_объявление_полей
    row = Class.new do
      extend Abacus::Macros
      field :base_rate, default: 0
      field :note
    end
    assert_equal 0, row.new.base_rate
    refute_predicate row.new, :note?
  end

  def test_s01e14_гем_собран_и_ничего_не_протекло
    assert_match(/\A\d+\.\d+\.\d+\z/, Abacus::VERSION)
    refute Object.const_defined?(:Ledger, false)
    refute Object.const_defined?(:Entry, false)
  end

  def test_финал_возвращает_ноль
    # Приёмка пройдена, если все проверки выше зелёные. Эта — просто подпись.
    assert true
  end
end
