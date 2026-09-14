# frozen_string_literal: true

# s01e05 — Свод по дорогам
#
#   cp starter.rb artifacts/reports.rb
#   make test
#
# Методы из s01e04 уже на месте. Ведомость — в support/ledger.rb.

module Abacus
  # Отчёт по ведомости. Ведомость хранит записи, отчёт отвечает на вопросы.
  #
  # Три обхода из сорока закрывают почти всё:
  #   map    — каждый элемент превращается в другой
  #   select — каждый элемент остаётся или уходит
  #   reduce — все элементы сходятся в одно значение
  class Report
    def initialize(ledger)
      @ledger = ledger
    end

    # ——— преобразование ———————————————————————————————————————

    # Платы по всем перевозкам, в порядке ведомости.
    def charges
      @ledger.map { |entry| entry[:charge] }
    end

    # Коды дорог без повторов, в порядке первого появления.
    def roads
      @ledger.map { |entry| entry[:road] }.uniq
    end

    # ——— отбор ———————————————————————————————————————————————

    def heavier_than(kg)
      @ledger.select { |entry| entry[:weight] > kg }
    end

    # reject, а не select с отрицанием: условие читается один раз и без «не».
    def lighter_than(kg)
      @ledger.reject { |entry| entry[:weight] > kg }
    end

    # Оба ответа за один обход. select + reject — это два обхода одного и того же.
    def split_by_weight(kg)
      @ledger.partition { |entry| entry[:weight] > kg }
    end

    # ——— свёртка ——————————————————————————————————————————————

    # Начальное значение обязательно: на пустой ведомости reduce без него
    # вернёт nil, а сумма ничего — это ноль.
    def total_charge
      @ledger.reduce(0) { |sum, entry| sum + entry[:charge] }
    end

    # reduce — не только сложение. Здесь он выбирает, а не складывает.
    def longest_cargo_name
      @ledger.reduce(nil) do |longest, entry|
        name = entry[:cargo]
        longest.nil? || name.length > longest.length ? name : longest
      end
    end

    # Средняя плата. Нет записей — нет средней: nil честнее нуля.
    def average_charge
      count = @ledger.count
      return nil if count.zero?

      total_charge.to_f / count
    end

    # ——— s01e05: своды ————————————————————————————————————————

    # Плата по каждой дороге: код дороги => сумма.
    #
    # TODO: сгруппировать и свернуть каждую группу. У Hash для второго шага
    #       есть готовый метод — искать в ri Hash.
    def charges_by_road
    end

    # Сколько раз какой груз встретился: груз => число.
    #
    # TODO: в Enumerable есть метод ровно для этого. Своего счётчика не нужно.
    def cargo_counts
    end

    # Три итога по каждой дороге: { "NTK" => { count:, weight:, charge: } }.
    #
    # TODO: за ОДИН обход. Три группировки подряд — три обхода.
    # TODO: накопитель несёт each_with_object; посмотри, в каком порядке он
    #       отдаёт блоку элемент и накопитель — он обратный к reduce.
    def summary_by_road
    end

    # Сверка с итогами, которые прислали сами дороги.
    # reported: { "NTK" => 12_040, ... }
    #
    # TODO: вернуть ТОЛЬКО расхождения: дорога => (наш итог − присланный).
    # TODO: сошлось — дороги в ответе нет вовсе.
    # TODO: дорога есть только у одной стороны — это тоже расхождение,
    #       а не повод её пропустить. У второй стороны там ноль.
    def mismatch(reported)
    end
  end
end
