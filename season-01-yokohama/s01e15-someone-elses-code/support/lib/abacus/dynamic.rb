# frozen_string_literal: true

module Abacus
  # Поиск по ведомости вопросами, которых никто не писал:
  #
  #   finder.find_by_road("SJI")
  #   finder.count_by_cargo("чай")
  #
  # Методов с такими именами в классе нет. Они разбираются на лету.
  class Finder
    # Модуль из support/: он разбирает имена total_by_*, и стоит в цепочке
    # позади Finder. Дойдёт до него только то, что Finder передал через super.
    include Totals

    FIELDS = %i[road cargo weight charge].freeze
    PATTERN = /\A(find|count)_by_(#{FIELDS.join("|")})\z/

    def initialize(entries)
      @entries = entries
    end

    def entries = @entries

    private

    # respond_to_missing? — вторая половина дела. Без неё respond_to? врёт,
    # а method(:find_by_road) не работает: Ruby спрашивает именно этот метод.
    def respond_to_missing?(name, include_private = false)
      PATTERN.match?(name.to_s) || super
    end

    def method_missing(name, *args, &block)
      match = PATTERN.match(name.to_s)
      # Не наше имя — отдаём дальше по цепочке. Без super NoMethodError
      # превратится в nil, и опечатка станет невидимой.
      return super unless match

      unless args.size == 1
        raise ArgumentError, "#{name} принимает ровно один аргумент (дано #{args.size})"
      end

      action, field = match.captures
      found = @entries.select { |entry| entry[field.to_sym] == args.first }
      action == "find" ? found : found.size
    end
  end
end
