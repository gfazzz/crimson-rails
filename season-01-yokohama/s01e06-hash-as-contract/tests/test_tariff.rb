# frozen_string_literal: true
#
# CRIMSON RAILS — s01e06, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/tariff.rb", __dir__)
SOL = File.expand_path("../solution/tariff.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ENTRY = { road: "SJI", cargo: "чай", weight: 1000, charge: 0 }.freeze

class TestInitialize < Minitest::Test
  def test_ставка_обязательна
    error = assert_raises(ArgumentError) { Abacus::Tariff.new }
    assert_match(/base_rate/, error.message,
                 "Ruby сам скажет, какого именованного аргумента не хватает, " \
                 "если у него нет умолчания. Тариф без ставки — не тариф.")
  end

  def test_умолчания_проставляются
    tariff = Abacus::Tariff.new(base_rate: 40)
    assert_equal 0, tariff.minimum
    assert_equal :up, tariff.rounding
  end

  def test_неизвестное_округление_отвергается_со_списком
    error = assert_raises(ArgumentError) { Abacus::Tariff.new(base_rate: 40, rounding: :sideways) }
    assert_includes error.message, "sideways", "Скажи, что получил."
    assert_includes error.message, "nearest", "И что бывает."
  end

  def test_тариф_заморожен
    assert_predicate Abacus::Tariff.new(base_rate: 40), :frozen?,
                     "Правило, которое можно поменять под ногами, нельзя проверить."
  end
end

class TestFrom < Minitest::Test
  def test_собирает_из_хеша
    rules = { base_rate: 40, minimum: 50 }
    tariff = Abacus::Tariff.from(**rules)
    assert_equal 40, tariff.base_rate
    assert_equal 50, tariff.minimum
  end

  def test_неизвестное_правило_это_ошибка_а_не_мусор
    error = assert_raises(ArgumentError) do
      Abacus::Tariff.from(base_rate: 40, mimimum: 50)   # опечатка в minimum
    end
    assert_includes error.message, "mimimum",
                    "Назови лишний ключ. Молчаливо проигнорированная опечатка — " \
                    "правило, которое не применилось, и никто не заметил."
    assert_includes error.message, "minimum", "И покажи, какие ключи известны."
  end

  def test_пустые_правила_всё_равно_требуют_ставку
    assert_raises(ArgumentError) { Abacus::Tariff.from }
  end
end

class TestWith < Minitest::Test
  def test_возвращает_новый_тариф
    original = Abacus::Tariff.new(base_rate: 40, minimum: 0)
    changed = original.with(minimum: 50)

    assert_equal 50, changed.minimum
    assert_equal 40, changed.base_rate, "Неизменённые правила переносятся."
    refute_same original, changed
  end

  def test_исходный_тариф_не_тронут
    original = Abacus::Tariff.new(base_rate: 40, minimum: 0)
    original.with(minimum: 50, base_rate: 99)
    assert_equal 0, original.minimum, "with не должен менять исходный тариф."
    assert_equal 40, original.base_rate
  end

  def test_неизвестное_правило_отвергается_и_здесь
    assert_raises(ArgumentError) { Abacus::Tariff.new(base_rate: 40).with(discont: 0.1) }
  end
end

class TestChargeFor < Minitest::Test
  def setup
    @tariff = Abacus::Tariff.new(base_rate: 40, rounding: :nearest)
  end

  def test_ставка_за_сто_килограммов
    assert_equal 400, @tariff.charge_for(ENTRY),
                 "1000 кг при ставке 40 сен за 100 кг — это 400 сен."
  end

  def test_надбавка_прибавляется_до_скидки
    # 400 + 100 = 500; скидка 10 % => 450
    assert_equal 450, @tariff.charge_for(ENTRY, surcharge: 100, discount: 0.1),
                 "Порядок счёта: надбавка, потом скидка. Обратный порядок даст 460."
  end

  def test_нижняя_граница_поднимает_плату
    tariff = Abacus::Tariff.new(base_rate: 1, minimum: 250, rounding: :nearest)
    assert_equal 250, tariff.charge_for(ENTRY),
                 "10 сен по ставке, но минимум 250 — платят 250."
  end

  def test_округление_вверх_вниз_и_к_ближайшему
    entry = { weight: 101 }
    up = Abacus::Tariff.new(base_rate: 40, rounding: :up)
    down = Abacus::Tariff.new(base_rate: 40, rounding: :down)
    near = Abacus::Tariff.new(base_rate: 40, rounding: :nearest)

    assert_equal 41, up.charge_for(entry),   "40.4 вверх — это 41."
    assert_equal 40, down.charge_for(entry), "40.4 вниз — это 40."
    assert_equal 40, near.charge_for(entry), "40.4 к ближайшему — это 40."
  end

  def test_скидка_вне_диапазона_отвергается
    assert_raises(ArgumentError) { @tariff.charge_for(ENTRY, discount: 1.5) }
    assert_raises(ArgumentError) { @tariff.charge_for(ENTRY, discount: -0.1) }
  end

  def test_опции_можно_передать_хешем_через_две_звезды
    options = { surcharge: 100, discount: 0.1 }
    assert_equal @tariff.charge_for(ENTRY, surcharge: 100, discount: 0.1),
                 @tariff.charge_for(ENTRY, **options),
                 "** раскрывает хеш в именованные аргументы. Без ** в Ruby 3 " \
                 "хеш поедет позиционным аргументом и метод его не примет."
  end

  def test_неизвестная_опция_не_проглатывается
    assert_raises(ArgumentError) { @tariff.charge_for(ENTRY, surchage: 100) }
  end

  def test_запись_без_веса_это_ошибка_а_не_ноль
    assert_raises(KeyError) { @tariff.charge_for({ road: "SJI" }) }
  end
end
