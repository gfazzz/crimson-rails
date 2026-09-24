# frozen_string_literal: true
#
# CRIMSON RAILS — s01e10, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/registry.rb", __dir__)
SOL = File.expand_path("../solution/registry.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

class RegistryTest < Minitest::Test
  def setup
    Abacus::Registry.reset!
  end
  alias teardown setup
end

class TestSelfInInstanceMethod < RegistryTest
  def test_register_возвращает_сам_реестр
    registry = Abacus::Registry.new
    result = registry.register("NTK", gauge: 1067, unit: :lb)
    assert_same registry, result,
                "self внутри метода экземпляра — сам объект. Возврат self " \
                "позволяет сцеплять вызовы"
  end

  def test_вызовы_сцепляются
    registry = Abacus::Registry.new
                              .register("NTK", gauge: 1067, unit: :lb)
                              .register("SJI", gauge: 1067, unit: :kan)
    assert_equal %w[NTK SJI], registry.codes
  end

  def test_повторная_запись_заменяет
    registry = Abacus::Registry.new
    registry.register("SJI", gauge: 1067, unit: :kan)
    registry.register("SJI", gauge: 1435, unit: :kg)
    assert_equal({ gauge: 1435, unit: :kg }, registry["SJI"])
    assert_equal ["SJI"], registry.codes, "И не плодит дубликат кода"
  end

  def test_неизвестная_дорога_это_KeyError_со_списком
    registry = Abacus::Registry.new.register("NTK", gauge: 1067, unit: :lb)
    error = assert_raises(KeyError) { registry["TKY"] }
    assert_includes error.message, "TKY"
    assert_includes error.message, "NTK"
  end

  def test_each_как_в_s01e03
    registry = Abacus::Registry.new.register("NTK", gauge: 1067, unit: :lb)
    seen = {}
    result = registry.each { |code, rules| seen[code] = rules }

    assert_equal({ "NTK" => { gauge: 1067, unit: :lb } }, seen)
    assert_same registry, result, "С блоком обход возвращает сам реестр"
    assert_kind_of Enumerator, Abacus::Registry.new.each, "Без блока — перечислитель"
  end
end

class TestSelfInClassBody < RegistryTest
  def test_реестр_один
    first = Abacus::Registry.instance
    second = Abacus::Registry.instance
    assert_same first, second,
                "Registry.instance обязан возвращать один и тот же объект: " \
                "@instance принадлежит самому классу"
  end

  def test_reset_забывает_реестр
    first = Abacus::Registry.instance
    Abacus::Registry.reset!
    refute_same first, Abacus::Registry.instance
  end

  def test_переменная_принадлежит_классу_а_не_экземпляру
    Abacus::Registry.instance
    refute_includes Abacus::Registry.new.instance_variables, :@instance,
                    "@instance в теле класса — переменная объекта-класса. " \
                    "У отдельной дороги её быть не должно"
  end
end

class TestSelfInSingletonClass < RegistryTest
  def test_короткий_доступ_работает_через_класс
    Abacus::Registry.register("SJI", gauge: 1067, unit: :kan)
    assert_equal({ gauge: 1067, unit: :kan }, Abacus::Registry["SJI"])
    assert_equal ["SJI"], Abacus::Registry.codes
  end

  def test_класс_и_экземпляр_говорят_об_одном_реестре
    Abacus::Registry.register("NTK", gauge: 1067, unit: :lb)
    assert_equal ["NTK"], Abacus::Registry.instance.codes,
                 "Короткий доступ — делегирование, а не второй склад"
  end

  def test_это_методы_класса_а_не_экземпляра
    assert_respond_to Abacus::Registry, :instance
    refute_respond_to Abacus::Registry.new, :instance,
                      "class << self определяет методы класса"
  end

  def test_обход_через_класс_тоже_работает
    Abacus::Registry.register("HYG", gauge: 1067, unit: :kg)
    codes = []
    Abacus::Registry.each { |code, _| codes << code }
    assert_equal ["HYG"], codes
  end
end

class TestSelfInBlock < RegistryTest
  def test_обычный_блок_self_не_меняет
    outer = self
    Abacus::Registry.register("NTK", gauge: 1067, unit: :lb)
    Abacus::Registry.each do |_code, _rules|
      assert_same outer, self,
                  "Блок не меняет self: внутри он тот же, что снаружи. " \
                  "Именно поэтому в блоке видны переменные вызывающего кода"
    end
  end

  def test_configure_выполняет_блок_в_контексте_реестра
    Abacus::Registry.configure do
      register("NTK", gauge: 1067, unit: :lb)
      register("SJI", gauge: 1067, unit: :kan)
    end

    assert_equal %w[NTK SJI], Abacus::Registry.codes,
                 "Внутри configure register вызывается без получателя — " \
                 "значит, self в блоке подменён на сам реестр"
  end

  def test_configure_возвращает_реестр
    result = Abacus::Registry.configure { register("KSN", gauge: 1067, unit: :kg) }
    assert_same Abacus::Registry.instance, result
  end

  def test_configure_видит_переменные_вызывающего_кода
    gauge = 1435
    Abacus::Registry.configure do
      register("TKY", gauge: gauge, unit: :kg)
    end
    assert_equal 1435, Abacus::Registry["TKY"][:gauge],
                 "Подмена self не отменяет замыкание: локальные переменные " \
                 "вызывающего кода по-прежнему видны"
  end
end
