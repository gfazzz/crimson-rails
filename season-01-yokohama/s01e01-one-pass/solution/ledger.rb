# frozen_string_literal: true

module Abacus
  # Ведомость Расчётной палаты: перевозки, которые надо свести.
  #
  # Запись — хеш:
  #   { road: "NTK", cargo: "уголь", weight: 1200, charge: 340 }
  class Ledger
    def initialize(entries)
      @entries = entries
    end

    # Один обход. Отдаёт каждую запись блоку.
    #
    # С блоком возвращает саму ведомость — чтобы вызовы можно было сцеплять.
    # Без блока возвращает перечислитель, а не падает: так делает весь Ruby.
    def each_entry
      return enum_for(:each_entry) unless block_given?

      @entries.each { |entry| yield entry }
      self
    end

    # Сумма того, что блок вернул на каждой записи.
    # Считает сама, но обходит — через each_entry: обход один на весь класс.
    def total_by
      raise ArgumentError, "total_by нужен блок: что именно суммировать" unless block_given?

      sum = 0
      each_entry { |entry| sum += yield(entry) }
      sum
    end

    # Сколько записей, на которых блок дал истину.
    # Истина по-рубистски: ложны только nil и false.
    def count_where
      raise ArgumentError, "count_where нужен блок: какие записи считать" unless block_given?

      found = 0
      each_entry { |entry| found += 1 if yield(entry) }
      found
    end
  end
end
