# frozen_string_literal: true

module Abacus
  # Ведомость Расчётной палаты.
  #
  # s01e01 — обход и два счёта поверх него.
  # s01e02 — правила: блок перестаёт быть безымянным.
  class Ledger
    def initialize(entries)
      @entries = entries
      @rules = {}
    end

    # ——— s01e01 ———————————————————————————————————————————————

    def each_entry
      return enum_for(:each_entry) unless block_given?

      @entries.each { |entry| yield entry }
      self
    end

    def total_by
      raise ArgumentError, "total_by нужен блок: что именно суммировать" unless block_given?

      sum = 0
      each_entry { |entry| sum += yield(entry) }
      sum
    end

    def count_where
      raise ArgumentError, "count_where нужен блок: какие записи считать" unless block_given?

      found = 0
      each_entry { |entry| found += 1 if yield(entry) }
      found
    end

    # ——— s01e02 ———————————————————————————————————————————————

    # Сохранить правило под именем.
    #
    # `&rule` в сигнатуре превращает блок в объект Proc — его можно положить
    # в хеш и вызвать через несколько часов. Без `&` блок вызвать позже нельзя:
    # yield работает только пока метод выполняется.
    def add_rule(name, &rule)
      raise ArgumentError, "правилу #{name.inspect} нужно тело: передай блок" unless block_given?

      @rules[name] = rule
      self
    end

    # Сохранить готовый вызываемый объект: lambda, proc или что угодно с call.
    # Ruby не спрашивает, какого объект класса, — спрашивает, что он умеет.
    def register(name, callable)
      unless callable.respond_to?(:call)
        raise ArgumentError,
              "правило #{name.inspect} должно отвечать на call, а #{callable.class} не отвечает"
      end

      @rules[name] = callable
      self
    end

    # Достать правило. Нет такого — говорим, какое искали и какие есть.
    def rule(name)
      @rules.fetch(name) do
        raise KeyError, "правило #{name.inspect} не задано; есть: #{rule_names.inspect}"
      end
    end

    def rule_names
      @rules.keys
    end

    # Применить сохранённое правило ко всей ведомости.
    #
    # Здесь нельзя написать total_by(&rule(name)): оператор `&` умеет
    # превращать в блок только Proc и то, у чего есть to_proc. Правило может
    # оказаться любым объектом с call — поэтому зовём call явно.
    def apply(name)
      found = rule(name)
      total_by { |entry| found.call(entry) }
    end
  end
end
