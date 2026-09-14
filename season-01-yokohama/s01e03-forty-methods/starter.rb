# frozen_string_literal: true

# s01e03 — Сорок методов даром
#
#   cp starter.rb artifacts/ledger.rb
#   make test

module Abacus
  # Ведомость Расчётной палаты.
  #
  # s01e01 — обход и два счёта поверх него.
  # s01e02 — правила: блок стал предметом.
  # s01e03 — ведомость объявлена перечислимой, и половина методов исчезла.
  class Ledger
    # TODO: объявить ведомость перечислимой — одна строка.

    def initialize(entries)
      @entries = entries
      @rules = {}
    end

    # Единственный обход в классе.
    #
    # TODO: переименовать each_entry в each — Enumerable ищет именно это имя.
    # TODO: оставить each_entry рабочим: договор из s01e01 никто не отменял.
    def each_entry
      return enum_for(:each_entry) unless block_given?

      @entries.each { |entry| yield entry }
      self
    end

    # ——— было двадцать строк, стало две ——————————————————————

    # TODO: переписать оба метода через Enumerable. Должно остаться по строке
    #       на метод; ручной цикл здесь больше не нужен.
    def total_by(&rule)
      raise ArgumentError, "total_by нужен блок: что именно суммировать" unless rule

      sum = 0
      each_entry { |entry| sum += rule.call(entry) }
      sum
    end

    def count_where(&rule)
      raise ArgumentError, "count_where нужен блок: какие записи считать" unless rule

      found = 0
      each_entry { |entry| found += 1 if rule.call(entry) }
      found
    end

    # ——— и стало возможным то, чего писать не хотелось ————————

    # n самых крупных по тому, что вернёт блок.
    #
    # TODO: одна строка средствами Enumerable. Без блока — ArgumentError.
    def top_by(n, &key)
    end

    # Свод по дорогам: код дороги => массив её записей.
    #
    # TODO: одна строка средствами Enumerable.
    def by_road
    end

    # ——— s01e02 ———————————————————————————————————————————————

    def add_rule(name, &rule)
      raise ArgumentError, "правилу #{name.inspect} нужно тело: передай блок" unless rule

      @rules[name] = rule
      self
    end

    def register(name, callable)
      unless callable.respond_to?(:call)
        raise ArgumentError,
              "правило #{name.inspect} должно отвечать на call, а #{callable.class} не отвечает"
      end

      @rules[name] = callable
      self
    end

    def rule(name)
      @rules.fetch(name) do
        raise KeyError, "правило #{name.inspect} не задано; есть: #{rule_names.inspect}"
      end
    end

    def rule_names = @rules.keys

    def apply(name)
      found = rule(name)
      total_by { |entry| found.call(entry) }
    end
  end
end
