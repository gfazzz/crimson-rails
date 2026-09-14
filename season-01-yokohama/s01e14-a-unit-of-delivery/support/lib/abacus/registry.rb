# frozen_string_literal: true

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

      def instance
        @instance ||= new
      end

      def reset!
        @instance = nil
      end

      # Короткий доступ: контора зовёт реестр, не думая о том, где он живёт.
      def register(...) = instance.register(...)
      def [](code) = instance[code]
      def codes = instance.codes
      def each(&block) = instance.each(&block)
      def configure(&block) = instance.configure(&block)
    end

    def initialize
      @roads = {}
    end

    # self внутри метода экземпляра — сам объект. Возвращаем его, чтобы
    # вызовы сцеплялись.
    def register(code, gauge:, unit:)
      @roads[code] = { gauge: gauge, unit: unit }
      self
    end

    def [](code)
      @roads.fetch(code) do
        raise KeyError, "дорога #{code.inspect} не в реестре; есть: #{codes.inspect}"
      end
    end

    def codes = @roads.keys

    def each(&block)
      return enum_for(:each) unless block

      @roads.each(&block)
      self
    end

    # Блок выполняется так, будто он написан внутри реестра: self в нём —
    # сам реестр, и register можно звать без получателя.
    def configure(&block)
      instance_eval(&block)
      self
    end
  end
end
