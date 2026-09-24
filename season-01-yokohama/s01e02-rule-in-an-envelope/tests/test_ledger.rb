# frozen_string_literal: true
#
# CRIMSON RAILS — s01e02, проверка.
# Свойства, а не текст: тест не читает твой файл как строку.

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

def ledger(count = 24) = Abacus::Ledger.new(build_entries(count))

class TestAddRule < Minitest::Test
  def test_сохранённое_правило_можно_вызвать_позже
    l = ledger
    l.add_rule(:charge) { |entry| entry[:charge] }
    saved = l.rule(:charge)

    assert_respond_to saved, :call,
                      "Правило должно храниться вызываемым объектом. " \
                      "Блок становится им, если принять его как &rule"
    assert_equal 340, saved.call({ road: "NTK", cargo: "чай", weight: 10, charge: 340 }),
                 "Вызов сохранённого правила должен делать то же, что делал бы блок"
  end

  def test_возвращает_себя_чтобы_правила_сцеплялись
    l = ledger
    result = l.add_rule(:a) { 1 }.add_rule(:b) { 2 }
    assert_same l, result, "add_rule должен возвращать саму ведомость"
    assert_equal %i[a b], l.rule_names, "Имена — в порядке добавления"
  end

  def test_без_блока_ошибка_с_именем_правила
    error = assert_raises(ArgumentError) { ledger.add_rule(:charge) }
    assert_includes error.message, "charge",
                    "В тексте ошибки должно быть видно, какому правилу не хватило тела"
  end

  def test_правило_замыкает_переменную_а_не_её_значение
    rate = 2
    l = ledger(3)
    l.add_rule(:scaled) { |entry| entry[:charge] * rate }
    before = l.apply(:scaled)

    rate = 3
    after = l.apply(:scaled)

    assert_equal before / 2 * 3, after,
                 "Правило должно видеть новое значение rate. Блок замыкает саму " \
                 "переменную, а не копию её значения на момент создания"
  end

  def test_повторное_имя_заменяет_правило
    l = ledger(4)
    l.add_rule(:x) { 1 }
    l.add_rule(:x) { 10 }
    assert_equal 40, l.apply(:x), "Второе правило под тем же именем заменяет первое"
    assert_equal [:x], l.rule_names, "И не плодит дубликат имени"
  end
end

class TestRegister < Minitest::Test
  def test_принимает_lambda
    l = ledger(5)
    l.register(:weight, ->(entry) { entry[:weight] })
    assert_predicate l.rule(:weight), :lambda?,
                     "Лямбда должна сохраниться лямбдой, а не превратиться в proc"
  end

  def test_блок_сохранённый_через_add_rule_это_proc_а_не_lambda
    l = ledger(5)
    l.add_rule(:weight) { |entry| entry[:weight] }
    refute_predicate l.rule(:weight), :lambda?,
                     "Блок, принятый через &rule, — proc. Это не придирка: proc " \
                     "прощает лишние аргументы и иначе ведёт себя с return"
  end

  def test_принимает_любой_объект_который_умеет_call
    callable = Class.new do
      def call(entry) = entry[:charge] * 2
    end.new

    l = ledger(6)
    l.register(:doubled, callable)
    expected = l.total_by { |e| e[:charge] } * 2
    assert_equal expected, l.apply(:doubled),
                 "Ruby спрашивает не «какого ты класса», а «что ты умеешь». " \
                 "Если здесь TypeError «expected Proc» — внутри apply стоит " \
                 "оператор &, а он работает только с Proc"
  end

  def test_объект_без_call_отвергается_с_указанием_класса
    error = assert_raises(ArgumentError) { ledger.register(:bad, "не правило") }
    assert_includes error.message, "String",
                    "В тексте ошибки должен быть класс того, что передали"
  end
end

class TestAmpersand < Minitest::Test
  def test_правило_из_блока_годится_в_оператор_амперсанда
    l = ledger(12)
    l.add_rule(:charge) { |entry| entry[:charge] }

    direct = l.total_by { |entry| entry[:charge] }
    via_ampersand = l.total_by(&l.rule(:charge))

    assert_equal direct, via_ampersand,
                 "Правило, сохранённое из блока, — это Proc, и оператор & обязан " \
                 "превращать его обратно в блок. Если тут падает TypeError, " \
                 "add_rule сохранил не сам блок, а что-то другое"
  end

  def test_символ_тоже_превращается_в_блок
    assert_equal %w[NTK SJI], %w[ntk sji].map(&:upcase),
                 "Symbol#to_proc — то же самое & на другом объекте. " \
                 "Эта проверка ничего не требует от твоего кода: она здесь, " \
                 "чтобы оператор & перестал казаться особым синтаксисом"
  end
end

class TestRuleLookup < Minitest::Test
  def test_неизвестное_имя_это_KeyError_со_списком_известных
    l = ledger
    l.add_rule(:charge) { |e| e[:charge] }
    error = assert_raises(KeyError) { l.rule(:weight) }
    assert_includes error.message, "weight", "Скажи, что искали"
    assert_includes error.message, "charge", "И что есть в наличии"
  end
end

class TestApply < Minitest::Test
  def test_применяет_сохранённое_правило_ко_всей_ведомости
    entries = build_entries(40)
    l = Abacus::Ledger.new(entries)
    l.add_rule(:charge) { |entry| entry[:charge] }
    expected = entries.map { |e| e[:charge] }.inject(0) { |a, v| a + v }
    assert_equal expected, l.apply(:charge)
  end

  def test_построен_на_total_by_а_не_на_своём_цикле
    counting = Class.new(Abacus::Ledger) do
      attr_reader :totals
      def total_by(&block)
        @totals = (@totals || 0) + 1
        super(&block)
      end
    end

    l = counting.new(build_entries(6))
    l.add_rule(:charge) { |entry| entry[:charge] }
    l.apply(:charge)
    assert_equal 1, l.totals.to_i,
                 "apply должен пользоваться total_by, а не считать сам"
  end

  def test_неизвестное_правило_падает_до_обхода
    assert_raises(KeyError) { ledger.apply(:nope) }
  end
end
