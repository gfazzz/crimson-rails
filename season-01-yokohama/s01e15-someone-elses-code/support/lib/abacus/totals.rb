# frozen_string_literal: true

module Abacus
  # Готовый модуль: суммы по полю.
  #
  #   finder.total_by_road("SJI")   # => сумма плат по этой дороге
  #
  # Разбирает свои имена тем же приёмом, что и Finder, и стоит в цепочке
  # ПОЗАДИ него. Значит, до него дойдёт только то, что Finder передал дальше
  # через super. Забыл super — модуля как не бывало.
  module Totals
    TOTAL_PATTERN = /\Atotal_by_(road|cargo)\z/

    private

    def method_missing(name, *args, &block)
      match = TOTAL_PATTERN.match(name.to_s)
      return super unless match

      raise ArgumentError, "#{name} принимает ровно один аргумент" unless args.size == 1

      field = match.captures.first.to_sym
      entries.select { |entry| entry[field] == args.first }
             .sum { |entry| entry[:charge] }
    end

    def respond_to_missing?(name, include_private = false)
      TOTAL_PATTERN.match?(name.to_s) || super
    end
  end
end
