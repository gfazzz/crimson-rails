# frozen_string_literal: true

module Abacus
  # Ведомость Расчётной палаты.
  #
  # s01e01 — обход и два счёта поверх него.
  # s01e02 — правила: блок стал предметом.
  # s01e03 — ведомость объявлена перечислимой, и половина методов исчезла.
  class Ledger
    include Enumerable

    def initialize(entries)
      @entries = entries
      @rules = {}
    end

    # Единственный обход в классе. Enumerable требует, чтобы он назывался
    # именно each: сорок методов модуля построены поверх этого имени.
    def each
      return enum_for(:each) unless block_given?

      @entries.each { |entry| yield entry }
      self
    end

    # Имя из s01e01 осталось: договор, однажды опубликованный наружу,
    # не ломают без нужды.
    alias each_entry each

    # ——— было двадцать строк, стало две ——————————————————————

    def total_by(&rule)
      raise ArgumentError, "total_by нужен блок: что именно суммировать" unless rule

      sum(&rule)
    end

    def count_where(&rule)
      raise ArgumentError, "count_where нужен блок: какие записи считать" unless rule

      count(&rule)
    end

    # ——— и стало возможным то, чего писать не хотелось ————————

    # n самых крупных по тому, что вернёт блок.
    def top_by(n, &key)
      raise ArgumentError, "top_by нужен блок: по чему отбирать" unless key

      max_by(n, &key)
    end

    # Свод по дорогам: код дороги → её записи.
    def by_road
      group_by { |entry| entry[:road] }
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
