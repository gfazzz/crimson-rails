# frozen_string_literal: true
#
# CRIMSON RAILS — s01e13, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/macros.rb", __dir__)
SOL = File.expand_path("../solution/macros.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

class TariffRow
  extend Abacus::Macros

  field :base_rate, default: 0
  field :minimum,   default: 0
  field :rounding,  default: :up
  field :note
end

# Наследник добавляет своё поле и не должен портить родителя.
class SJITariffRow < TariffRow
  field :kan_rate, default: 3.75
end

class TestFieldMacro < Minitest::Test
  def test_поле_читается
    assert_equal 40, TariffRow.new(base_rate: 40).base_rate
  end

  def test_умолчание_подставляется
    row = TariffRow.new(base_rate: 40)
    assert_equal 0, row.minimum
    assert_equal :up, row.rounding
    assert_nil row.note, "Поле без умолчания — nil"
  end

  def test_умолчания_не_перепутались_между_полями
    row = TariffRow.new
    assert_equal 0, row.minimum
    assert_equal :up, row.rounding,
                 "Каждый созданный метод замыкает СВОЁ умолчание. Если тут " \
                 "одно и то же значение у всех полей — блок замкнул общую " \
                 "переменную вместо своей"
  end

  def test_предикат
    assert_predicate TariffRow.new(base_rate: 40), :base_rate?
    refute_predicate TariffRow.new, :note?
    refute_predicate TariffRow.new(note: false), :note?
    assert_predicate TariffRow.new(note: 0), :note?, "Ноль — не пусто (s01e01)"
  end

  def test_field_возвращает_класс
    klass = Class.new { extend Abacus::Macros }
    assert_same klass, klass.field(:a), "Чтобы объявления сцеплялись"
  end

  def test_список_полей
    assert_equal %i[base_rate minimum rounding note], TariffRow.fields
  end
end

class TestRealMethods < Minitest::Test
  def test_методы_настоящие_а_не_призраки
    assert_includes TariffRow.instance_methods, :base_rate,
                    "define_method создаёт настоящий метод: он виден в " \
                    "instance_methods, в отличие от разбора имён в s01e12"
    assert_includes TariffRow.instance_methods, :base_rate?
  end

  def test_method_объект_работает
    row = TariffRow.new(base_rate: 40)
    assert_equal 40, row.method(:base_rate).call
  end

  def test_method_missing_не_участвует
    strict = Class.new(TariffRow) do
      def method_missing(name, *) = raise("до method_missing дойти не должно: #{name}")
      def respond_to_missing?(*) = false
    end

    assert_equal 40, strict.new(base_rate: 40).base_rate,
                 "Метод создан заранее, поэтому поиск находит его сразу " \
                 "и до перехватчика дело не доходит"
  end

  def test_respond_to_работает_без_усилий
    assert_respond_to TariffRow.new, :rounding
    refute_respond_to TariffRow.new, :nonsense
  end
end

class TestInitialize < Minitest::Test
  def test_неизвестное_поле_отвергается
    error = assert_raises(ArgumentError) { TariffRow.new(base_rate: 40, mimimum: 5) }
    assert_includes error.message, "mimimum", "Назови лишнее поле"
    assert_includes error.message, "minimum", "И покажи, какие есть"
  end

  def test_без_полей_тоже_можно
    assert_equal 0, TariffRow.new.base_rate
  end
end

class TestAccessByName < Minitest::Test
  def test_обращение_по_имени
    row = TariffRow.new(base_rate: 40)
    assert_equal 40, row[:base_rate]
    assert_equal 40, row["base_rate"], "Имя поля можно дать и строкой"
  end

  def test_обращение_по_имени_учитывает_умолчание
    assert_equal :up, TariffRow.new[:rounding],
                 "Значение берётся через созданный метод, а не напрямую " \
                 "из хранилища: иначе умолчание не применится"
  end

  def test_неизвестное_имя_это_KeyError
    error = assert_raises(KeyError) { TariffRow.new[:clerk] }
    assert_includes error.message, "clerk"
  end

  def test_приватные_методы_полями_не_являются
    klass = Class.new(TariffRow) do
      private def secret = "не поле"
    end
    assert_raises(KeyError) { klass.new[:secret] }
  end

  def test_to_h_возвращает_все_поля
    assert_equal({ base_rate: 40, minimum: 0, rounding: :up, note: nil },
                 TariffRow.new(base_rate: 40).to_h)
  end
end

class TestInheritance < Minitest::Test
  def test_наследник_видит_поля_родителя
    row = SJITariffRow.new(base_rate: 40)
    assert_equal 40, row.base_rate
    assert_equal :up, row.rounding
  end

  def test_наследник_добавляет_своё
    assert_equal 3.75, SJITariffRow.new.kan_rate
    assert_includes SJITariffRow.fields, :kan_rate
  end

  def test_родитель_не_испорчен
    refute_includes TariffRow.fields, :kan_rate,
                    "Наследник получает КОПИЮ списка полей. Общий список " \
                    "означал бы, что наследник дописывает поля родителю"
    assert_raises(ArgumentError) { TariffRow.new(kan_rate: 1) }
  end
end
