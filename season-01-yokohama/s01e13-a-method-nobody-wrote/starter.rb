# frozen_string_literal: true

# s01e13 — Метод, которого не писали
#
#   cp starter.rb artifacts/macros.rb
#   make test

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

    # TODO: наследник должен получить КОПИЮ списков, а не общий с родителем
    #       и не пустой. Ruby зовёт этот хук при наследовании (s01e09).
    def inherited(subclass)
    end

    # TODO: запомнить поле и его умолчание.
    # TODO: создать метод чтения. Блок define_method — замыкание: он помнит
    #       name и default. С обычным def так не выйдет.
    # TODO: создать предикат name? — истина, если значение не nil и не false.
    # TODO: вернуть self.
    def field(name, default: nil)
    end

    module InstanceMethods
      # TODO: неизвестное поле — ArgumentError со списком известных (s01e06).
      def initialize(**attributes)
      end

      # Обращение по имени поля. public_send, а не send: приватные методы
      # полями не являются, и лазейку сюда открывать незачем.
      # Обращение по имени поля.
      #
      # TODO: неизвестное поле — KeyError со списком.
      # TODO: значение брать через созданный метод, а не из @attributes —
      #       иначе умолчание не сработает.
      # TODO: public_send, а не send: приватные методы полями не являются.
      def [](name)
      end

      # TODO: все поля хешем, с умолчаниями.
      def to_h
      end
    end
  end
end
