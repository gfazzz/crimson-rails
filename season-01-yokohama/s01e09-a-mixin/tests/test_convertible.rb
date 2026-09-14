# frozen_string_literal: true
#
# CRIMSON RAILS — s01e09, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/convertible.rb", __dir__)
SOL = File.expand_path("../solution/convertible.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

# Класс-хозяин. Модуль не знает, как он устроен, — только что у него есть
# weight и unit.
class Shipment
  include Abacus::Convertible

  attr_reader :weight, :unit

  def initialize(weight, unit)
    @weight = weight
    @unit = unit
  end
end

class RoundedShipment < Shipment
  prepend Abacus::Rounded
end

class TestConversion < Minitest::Test
  def test_килограммы_остаются_килограммами
    assert_in_delta 800.0, Shipment.new(800, :kg).weight_kg, 1e-9
  end

  def test_кан_в_килограммы
    assert_in_delta 3.75, Shipment.new(1, :kan).weight_kg, 1e-9,
                    "Один кан — три и три четверти килограмма."
  end

  def test_фунты_в_килограммы
    assert_in_delta 45.359237, Shipment.new(100, :lb).weight_kg, 1e-6
  end

  def test_из_одной_единицы_в_другую
    assert_in_delta 1.0, Shipment.new(3.75, :kg).weight_in(:kan), 1e-9
    assert_in_delta 800.0, Shipment.new(800, :kg).weight_in(:kg), 1e-9
  end

  def test_круговой_пересчёт
    ship = Shipment.new(213, :kan)
    assert_in_delta 213.0, ship.weight_in(:kan), 1e-9,
                    "Туда и обратно должно давать исходное число."
  end

  def test_неизвестная_единица_отвергается_со_списком
    error = assert_raises(ArgumentError) { Shipment.new(1, :shaku).weight_kg }
    assert_includes error.message, "shaku", "Скажи, что получил."
    assert_includes error.message, "kan", "И что бывает."
  end

  def test_неизвестная_целевая_единица_тоже
    assert_raises(ArgumentError) { Shipment.new(1, :kg).weight_in(:shaku) }
  end
end

class TestIncludeHook < Minitest::Test
  def test_класс_получил_метод_класса
    assert_respond_to Shipment, :units,
                      "include добавляет методы экземпляра. Методы класса " \
                      "приходят через хук included и extend."
    assert_equal %i[kg kan lb], Shipment.units
  end

  def test_метод_класса_не_стал_методом_экземпляра
    refute_respond_to Shipment.new(1, :kg), :units,
                      "units — про класс, а не про отдельную перевозку."
  end

  def test_модуль_в_цепочке_предков
    assert_includes Shipment.ancestors, Abacus::Convertible
  end

  def test_это_примесь_а_не_наследование
    assert_equal Object, Shipment.superclass,
                 "Подмешивание не меняет родителя: у класса по-прежнему один предок-класс."
    refute_kind_of Class, Abacus::Convertible,
                   "Модуль — не класс: его нельзя создать и от него нельзя наследовать."
    assert_raises(NoMethodError) { Abacus::Convertible.new }
  end
end

class TestPrepend < Minitest::Test
  def test_prepend_округляет_через_super
    assert_in_delta 798.75, Shipment.new(213, :kan).weight_kg, 1e-9
    assert_equal 799, RoundedShipment.new(213, :kan).weight_kg,
                 "Округлённый вариант обязан пользоваться исходным расчётом " \
                 "через super, а не считать заново."
  end

  def test_prepend_встаёт_перед_классом
    ancestors = RoundedShipment.ancestors
    assert_operator ancestors.index(Abacus::Rounded), :<, ancestors.index(RoundedShipment),
                    "prepend ставит модуль ПЕРЕД классом — поэтому его метод " \
                    "перехватывает вызов, а super идёт дальше по цепочке."
  end

  def test_include_в_тот_же_класс_не_сработал_бы
    with_include = Class.new do
      include Abacus::Rounded
      def weight_kg = 798.75
    end
    with_prepend = Class.new do
      prepend Abacus::Rounded
      def weight_kg = 798.75
    end

    assert_in_delta 798.75, with_include.new.weight_kg, 1e-9,
                    "include ставит модуль ПОЗАДИ класса: собственный метод класса " \
                    "побеждает, и округление не применяется. Это не ошибка твоего " \
                    "кода — это и есть разница между include и prepend."
    assert_equal 799, with_prepend.new.weight_kg,
                 "prepend ставит модуль ПЕРЕД классом — вызов перехвачен, " \
                 "а super идёт в метод класса."
  end

  def test_extend_на_одном_объекте
    ship = Shipment.new(213, :kan)
    ship.extend(Abacus::Rounded)
    assert_equal 799, ship.weight_kg,
                 "extend подмешивает модуль в один объект: он встаёт перед его " \
                 "классом, и super работает так же."
    assert_kind_of Float, Shipment.new(213, :kan).weight_kg,
                   "Соседние объекты того же класса не затронуты."
  end

  def test_исходный_метод_не_испорчен
    assert_in_delta 798.75, Shipment.new(213, :kan).weight_kg, 1e-9,
                    "Округление не должно переписывать исходный расчёт."
  end
end
