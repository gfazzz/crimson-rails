# frozen_string_literal: true

module Abacus
  # Приведение ключей.
  #
  # Японская контора пишет ключи латиницей — строками. Палата пишет символами.
  # Для Ruby это разные ключи, и две одинаковые с виду записи одинаковыми
  # не являются.
  module Keys
    # Рекурсивно привести ключи хешей к символам.
    # Значения не трогаются: строка-значение остаётся строкой.
    def self.symbolize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), acc|
          acc[key.respond_to?(:to_sym) ? key.to_sym : key] = symbolize(nested)
        end
      when Array
        value.map { |item| symbolize(item) }
      else
        value
      end
    end

    # Обратно — в строки: так ведомость отправляют в японскую контору.
    def self.stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), acc|
          acc[key.to_s] = stringify(nested)
        end
      when Array
        value.map { |item| stringify(item) }
      else
        value
      end
    end

    # Две записи об одной перевозке, даже если ключи набраны по-разному.
    def self.same_row?(first, second)
      symbolize(first) == symbolize(second)
    end

    # Убрать записи, отличающиеся только видом ключей.
    # Остаётся первая встретившаяся, в исходном виде и на исходном месте.
    def self.dedupe(rows)
      seen = []
      rows.each_with_object([]) do |row, kept|
        normalized = symbolize(row)
        next if seen.include?(normalized)

        seen << normalized
        kept << row
      end
    end
  end
end
