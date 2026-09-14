# frozen_string_literal: true
#
# CRIMSON RAILS — s01e12, проверка.

require "minitest/autorun"
require_relative "../support/totals"

ART = File.expand_path("../artifacts/dynamic.rb", __dir__)
SOL = File.expand_path("../solution/dynamic.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ENTRIES = [
  { road: "SJI", cargo: "чай",   weight: 800,  charge: 40 },
  { road: "SJI", cargo: "уголь", weight: 2400, charge: 310 },
  { road: "NTK", cargo: "чай",   weight: 600,  charge: 95 },
  { road: "HYG", cargo: "рис",   weight: 1500, charge: 180 }
].freeze

def finder = Abacus::Finder.new(ENTRIES)

class TestFindBy < Minitest::Test
  def test_поиск_по_дороге
    assert_equal ENTRIES.values_at(0, 1), finder.find_by_road("SJI")
  end

  def test_поиск_по_грузу
    assert_equal ENTRIES.values_at(0, 2), finder.find_by_cargo("чай")
  end

  def test_поиск_по_числовому_полю
    assert_equal [ENTRIES[0]], finder.find_by_charge(40)
  end

  def test_ничего_не_нашлось_пустой_массив
    assert_equal [], finder.find_by_road("TKY")
  end

  def test_порядок_ведомости_сохраняется
    assert_equal ENTRIES.values_at(0, 2), finder.find_by_cargo("чай")
  end
end

class TestCountBy < Minitest::Test
  def test_считает
    assert_equal 2, finder.count_by_road("SJI")
    assert_equal 1, finder.count_by_cargo("рис")
    assert_equal 0, finder.count_by_road("TKY")
  end

  def test_счёт_и_поиск_согласованы
    assert_equal finder.find_by_road("SJI").size, finder.count_by_road("SJI")
  end
end

class TestUnknownNames < Minitest::Test
  def test_неизвестное_поле_это_NoMethodError
    error = assert_raises(NoMethodError) { finder.find_by_clerk("Ито") }
    assert_includes error.message, "find_by_clerk",
                    "Сообщение должно называть метод, которого нет. " \
                    "Это даёт super — без него опечатка вернёт nil."
  end

  def test_совсем_чужое_имя_тоже
    assert_raises(NoMethodError) { finder.съешь_ещё_этих_булочек }
  end

  def test_похожее_но_не_то_имя
    assert_raises(NoMethodError) { finder.find_by_ }
    assert_raises(NoMethodError) { finder.find_by_road_and_cargo("SJI", "чай") }
  end

  def test_обычные_методы_не_сломаны
    assert_equal ENTRIES, finder.entries
    assert_kind_of String, finder.to_s
    assert_respond_to finder, :inspect
  end
end

class TestArguments < Minitest::Test
  def test_нужен_ровно_один_аргумент
    assert_raises(ArgumentError) { finder.find_by_road }
    assert_raises(ArgumentError) { finder.find_by_road("SJI", "NTK") }
  end

  def test_в_сообщении_видно_какой_метод
    error = assert_raises(ArgumentError) { finder.count_by_cargo }
    assert_includes error.message, "count_by_cargo"
  end
end

# Totals стоит в цепочке позади Finder: его имена доходят только через super.
class TestSuperInTheChain < Minitest::Test
  def test_чужие_имена_доходят_до_модуля_позади
    assert_equal 350, finder.total_by_road("SJI"),
                 "total_by_* разбирает модуль Totals, который стоит ПОЗАДИ Finder. " \
                 "Если method_missing не передаёт незнакомое имя через super, " \
                 "модуль не получит ничего и метод исчезнет."
    assert_equal 135, finder.total_by_cargo("чай")
  end

  def test_respond_to_видит_имена_модуля
    assert_respond_to finder, :total_by_road,
                      "respond_to_missing? тоже обязан звать super: иначе " \
                      "объект отвечает на вопрос, но отрицает это."
  end

  def test_method_объект_для_имени_модуля
    assert_equal 350, finder.method(:total_by_road).call("SJI")
  end

  def test_имя_неизвестное_обоим_по_прежнему_падает
    assert_raises(NoMethodError) { finder.total_by_clerk("Ито") }
  end
end

class TestRespondTo < Minitest::Test
  def test_respond_to_говорит_правду_про_разбираемые_имена
    assert_respond_to finder, :find_by_road
    assert_respond_to finder, :count_by_cargo,
                      "Объект отвечает на вопрос — значит, respond_to? обязан " \
                      "это подтверждать."
  end

  def test_respond_to_не_врёт_про_остальные
    refute_respond_to finder, :find_by_clerk
    refute_respond_to finder, :нет_такого_метода
  end

  def test_method_объект_работает
    m = finder.method(:find_by_road)
    assert_equal ENTRIES.values_at(0, 1), m.call("SJI"),
                 "method() опирается на respond_to_missing?, а не на respond_to?. " \
                 "Если здесь NameError — переопределён не тот метод."
  end

  def test_method_объект_можно_передать_блоком
    m = finder.method(:count_by_road)
    assert_equal [2, 1], %w[SJI NTK].map(&m),
                 "У Method есть to_proc — приём из s01e02."
  end

  def test_method_для_неизвестного_имени_падает
    assert_raises(NameError) { finder.method(:find_by_clerk) }
  end

  def test_служебные_методы_закрыты
    refute_includes finder.public_methods, :method_missing,
                    "method_missing — служебный метод, его делают приватным."
    refute_includes finder.public_methods, :respond_to_missing?,
                    "respond_to_missing? тоже: Ruby зовёт его сам, " \
                    "а снаружи спрашивают respond_to?."
  end
end
