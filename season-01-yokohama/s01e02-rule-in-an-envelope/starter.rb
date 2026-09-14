# frozen_string_literal: true

# s01e02 — Действие в конверте
#
#   cp starter.rb artifacts/ledger.rb
#   make test
#
# Методы из s01e01 уже на месте — они понадобятся. Допиши пять новых.

module Abacus
  class Ledger
    def initialize(entries)
      @entries = entries
      @rules = {}
    end

    # ——— s01e01, готово ———————————————————————————————————————

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

    # ——— s01e02, твоя работа ——————————————————————————————————

    # Сохранить правило под именем, чтобы применить его позже.
    #
    # TODO: принять блок объектом — `&rule` в сигнатуре.
    # TODO: положить в @rules под ключом name.
    # TODO: без блока — ArgumentError с внятным текстом.
    # TODO: вернуть self.
    def add_rule(name)
    end

    # Сохранить готовый вызываемый объект: lambda, proc или свой класс с call.
    #
    # TODO: проверять не класс, а умение: respond_to?(:call).
    # TODO: не умеет — ArgumentError, в тексте назвать класс объекта.
    def register(name, callable)
    end

    # Достать правило по имени.
    #
    # TODO: нет такого — KeyError с именем и списком имеющихся.
    def rule(name)
    end

    # Имена сохранённых правил, в порядке добавления.
    def rule_names
    end

    # Применить сохранённое правило ко всей ведомости и вернуть сумму.
    #
    # TODO: достать правило один раз, а не на каждой записи.
    # TODO: вызвать его через call — оператор `&` тут не подойдёт, и в теории
    #       сказано почему.
    # TODO: считать через total_by, а не своим циклом.
    def apply(name)
    end
  end
end
