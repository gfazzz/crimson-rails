# frozen_string_literal: true

# s01e01 — Один обход
#
# Скопируй этот файл в artifacts/ и допиши три метода:
#   cp starter.rb artifacts/ledger.rb
#
# Проверка: make test

module Abacus
  # Ведомость Расчётной палаты: перевозки, которые надо свести.
  #
  # Запись — хеш:
  #   { road: "NTK", cargo: "уголь", weight: 1200, charge: 340 }
  class Ledger
    def initialize(entries)
      @entries = entries
    end

    # Один обход: отдать каждую запись блоку.
    #
    # TODO: вызвать блок для каждой записи.
    # TODO: вернуть саму ведомость, а не массив записей.
    # TODO: если блок не передан — вернуть перечислитель (enum_for), а не упасть.
    def each_entry
    end

    # Сумма того, что блок вернул на каждой записи.
    #
    # TODO: без блока — поднять ArgumentError с внятным текстом.
    # TODO: обходить через each_entry, а не заводить свой цикл по @entries.
    def total_by
    end

    # Сколько записей, на которых блок дал истину.
    #
    # TODO: без блока — поднять ArgumentError.
    # TODO: истина по-рубистски: ложны только nil и false. Ноль — истина.
    def count_where
    end
  end
end
