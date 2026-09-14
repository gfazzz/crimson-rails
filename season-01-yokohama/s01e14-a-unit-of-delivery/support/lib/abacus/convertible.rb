# frozen_string_literal: true

module Abacus
  # Пересчёт веса между единицами.
  #
  # Подмешивается в любой класс, у которого есть weight и unit. Модуль не знает,
  # как эти методы устроены, и знать не должен: он описывает роль, а не
  # устройство.
  module Convertible
    # Сколько килограммов в одной единице.
    IN_KG = { kg: 1.0, kan: 3.75, lb: 0.45359237 }.freeze

    # Хук: вызывается в момент include. Через него класс-хозяин получает
    # ещё и методы класса — сам include их не добавляет.
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def units = Convertible::IN_KG.keys
    end

    def weight_kg
      weight * Convertible.factor_for(unit)
    end

    def weight_in(target)
      weight_kg / Convertible.factor_for(target)
    end

    def self.factor_for(unit)
      IN_KG.fetch(unit) do
        raise ArgumentError, "единица #{unit.inspect} неизвестна; есть: #{IN_KG.keys.inspect}"
      end
    end
  end

  # Округление веса до целых килограммов.
  #
  # Подмешивается через prepend: модуль встаёт ПЕРЕД классом в цепочке, и
  # super из него зовёт исходный метод. Через include так не получится —
  # метод класса перекрыл бы метод модуля.
  module Rounded
    def weight_kg
      super.round
    end
  end
end
