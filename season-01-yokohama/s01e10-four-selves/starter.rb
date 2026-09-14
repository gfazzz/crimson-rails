# frozen_string_literal: true

# s01e10 — Четыре self
#
#   cp starter.rb artifacts/registry.rb
#   make test

module Abacus
  # Реестр дорог: колея и единица веса у каждой.
  #
  # Реестр один на контору, но единственность сделана не «классом-складом»,
  # а обычным объектом, к которому класс даёт короткий доступ. Объект можно
  # создать второй раз — в тестах это спасает.
  class Registry
    # Здесь self — сам класс Registry, и @instance принадлежит ему:
    # это переменная объекта-класса, а не переменная экземпляра дороги.
    @instance = nil

    class << self
      # А здесь self — одиночный класс Registry. Всё, что определено внутри,
      # становится методами класса.

      # TODO: instance — один и тот же объект при каждом вызове.
      def instance
      end

      # TODO: reset! — забыть его (нужен тестам).
      def reset!
      end

      # TODO: короткий доступ. Registry.register(...) должен делать то же,
      #       что Registry.instance.register(...). Пять методов-делегатов.
    end

    def initialize
      @roads = {}
    end

    # self внутри метода экземпляра — сам объект. Возвращаем его, чтобы
    # вызовы сцеплялись.
    # TODO: запомнить дорогу и вернуть себя, чтобы вызовы сцеплялись.
    def register(code, gauge:, unit:)
    end

    # TODO: неизвестная дорога — KeyError с кодом и списком известных.
    def [](code)
    end

    # TODO: коды дорог.
    def codes
    end

    # TODO: обход пар «код => правила». Как в s01e03: без блока —
    #       перечислитель, с блоком — self.
    def each(&block)
    end

    # Блок должен выполняться так, будто он написан ВНУТРИ реестра:
    #
    #   Registry.configure do
    #     register("NTK", gauge: 1067, unit: :lb)   # без получателя!
    #   end
    #
    # TODO: обычный block.call здесь не подойдёт — self внутри блока не
    #       меняется. Нужен способ выполнить блок в контексте объекта.
    def configure(&block)
    end
  end
end
