# frozen_string_literal: true
#
# CRIMSON RAILS — s01e08, проверка.

require "minitest/autorun"
require "set"
require_relative "../support/keys"

ART = File.expand_path("../artifacts/entry.rb", __dir__)
SOL = File.expand_path("../solution/entry.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

FIELDS = { road: "SJI", cargo: "чай", weight: 800, charge: 40 }.freeze

def entry(**overrides) = Abacus::Entry.new(**FIELDS.merge(overrides))

class TestConstruction < Minitest::Test
  def test_поля_читаются
    e = entry
    assert_equal "SJI", e.road
    assert_equal "чай", e.cargo
    assert_equal 800, e.weight
    assert_equal 40, e.charge
  end

  def test_все_поля_обязательны
    error = assert_raises(ArgumentError) { Abacus::Entry.new(road: "SJI") }
    assert_match(/cargo|weight|charge/, error.message,
                 "Именованные аргументы без умолчаний — язык сам потребует их.")
  end

  def test_запись_неизменяема
    assert_predicate entry, :frozen?,
                     "Объект-значение не меняется: иначе две «равные» записи " \
                     "перестанут быть равными у тебя за спиной."
  end

  def test_поля_нельзя_записать
    refute_respond_to entry, :road=, "attr_reader, а не attr_accessor."
  end

  def test_собирается_из_хеша_с_любыми_ключами
    japanese = { "road" => "SJI", "cargo" => "чай", "weight" => 800, "charge" => 40 }
    assert_equal entry, Abacus::Entry.from(japanese)
    assert_equal entry, Abacus::Entry.from(FIELDS)
  end

  def test_лишние_ключи_в_хеше_не_мешают
    row = FIELDS.merge("clerk" => "Ито", "line" => 388)
    assert_equal entry, Abacus::Entry.from(row),
                 "В ведомости встречаются чужие поля. Запись берёт свои."
  end

  def test_to_h_возвращает_поля
    assert_equal FIELDS, entry.to_h
  end
end

class TestEquality < Minitest::Test
  def test_одинаковые_поля_значит_равны
    assert_equal entry, entry
    assert entry == entry, "Равенство по значению, а не по тождеству."
  end

  def test_разные_поля_значит_не_равны
    refute_equal entry, entry(charge: 41)
  end

  def test_чужой_класс_не_равен_и_не_падает
    other = Struct.new(:road, :cargo, :weight, :charge, keyword_init: true)
                  .new(**FIELDS)
    refute_equal entry, other,
                 "Объект с теми же полями, но другого класса, равным не считается."
    assert_equal false, entry == 42, "Сравнение с чем угодно возвращает false, а не исключение."
    assert_equal false, entry == nil
  end

  def test_eql_и_hash_согласованы
    a = entry
    b = entry
    assert a.eql?(b), "eql? должен вести себя как ==."
    assert_equal a.hash, b.hash,
                 "Равные объекты обязаны иметь равный хеш-код. Иначе Hash, Set " \
                 "и uniq перестанут их находить."
  end

  def test_разные_записи_как_правило_имеют_разный_хеш
    refute_equal entry.hash, entry(charge: 41).hash
  end

  def test_класс_входит_в_хеш_код
    twin = Class.new(Abacus::Entry)
    refute_equal entry.hash, twin.new(**FIELDS).hash,
                 "Наследник с теми же полями — другой объект: класс должен " \
                 "участвовать в хеш-коде."
  end
end

class TestCollections < Minitest::Test
  def test_uniq_теперь_находит_двойника
    japanese = Abacus::Entry.from("road" => "SJI", "cargo" => "чай",
                                  "weight" => 800, "charge" => 40)
    british = Abacus::Entry.from(FIELDS)

    assert_equal 1, [japanese, british].uniq.size,
                 "Ради этого и писалась вся серия: две записи об одной перевозке " \
                 "теперь одинаковы для языка, а не только для глаза."
  end

  def test_годится_ключом_хеша
    index = { entry => "строка 388" }
    assert_equal "строка 388", index[entry],
                 "Другой объект с теми же полями должен находить ту же запись."
  end

  def test_годится_элементом_множества
    assert_equal 1, Set[entry, entry].size
  end

  def test_group_by_сводит_равные_вместе
    rows = [entry, entry(charge: 41), entry]
    assert_equal 2, rows.group_by(&:itself).size
  end
end

class TestPrinting < Minitest::Test
  def test_to_s_для_человека
    text = entry.to_s
    assert_includes text, "SJI"
    assert_includes text, "чай"
    refute_includes text, "#<", "to_s читают люди: ни решёток, ни имени класса."
    refute_includes text, "road=", "И без имён полей."
  end

  def test_inspect_для_программиста
    text = entry.inspect
    assert_includes text, "Abacus::Entry", "Видно класс."
    assert_includes text, "road", "Видны имена полей."
    assert_includes text, '"SJI"', "Строковые значения — в кавычках, как в inspect."
  end

  def test_to_s_и_inspect_это_разные_строки
    refute_equal entry.to_s, entry.inspect,
                 "Две разные задачи: показать человеку и показать программисту."
  end

  def test_интерполяция_зовёт_to_s
    assert_equal entry.to_s, "#{entry}"
  end
end
