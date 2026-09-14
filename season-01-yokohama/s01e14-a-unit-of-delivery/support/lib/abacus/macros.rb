# frozen_string_literal: true

module Abacus
  # Объявление полей одной строкой:
  #
  #   class TariffRow
  #     extend Abacus::Macros
  #     field :base_rate, default: 0
  #   end
  #
  # В отличие от s01e12, методы здесь создаются НАСТОЯЩИЕ — один раз, при
  # чтении класса. Дальше они ничем не отличаются от написанных руками.
  module Macros
    def self.extended(base)
      base.include(InstanceMethods)
    end

    # Списки принадлежат самому классу (s01e10). Наследник получает копию,
    # а не общий список: иначе он дописал бы поле родителю.
    def fields = @fields ||= []
    def defaults = @defaults ||= {}

    def inherited(subclass)
      super
      subclass.instance_variable_set(:@fields, fields.dup)
      subclass.instance_variable_set(:@defaults, defaults.dup)
    end

    def field(name, default: nil)
      name = name.to_sym
      fields << name unless fields.include?(name)
      defaults[name] = default

      # Блок define_method — замыкание: он помнит name и default той
      # итерации, в которой создан. С обычным def так не выйдет: тело метода
      # не видит локальных переменных места объявления.
      define_method(name) do
        @attributes.fetch(name) { default }
      end

      define_method(:"#{name}?") do
        value = public_send(name)
        !value.nil? && value != false
      end

      self
    end

    module InstanceMethods
      def initialize(**attributes)
        unknown = attributes.keys - self.class.fields
        unless unknown.empty?
          raise ArgumentError,
                "неизвестные поля: #{unknown.inspect}; есть: #{self.class.fields.inspect}"
        end

        @attributes = attributes
      end

      # Обращение по имени поля. public_send, а не send: приватные методы
      # полями не являются, и лазейку сюда открывать незачем.
      def [](name)
        unless self.class.fields.include?(name.to_sym)
          raise KeyError, "поля #{name.inspect} нет; есть: #{self.class.fields.inspect}"
        end

        public_send(name)
      end

      def to_h
        self.class.fields.to_h { |name| [name, public_send(name)] }
      end
    end
  end
end
