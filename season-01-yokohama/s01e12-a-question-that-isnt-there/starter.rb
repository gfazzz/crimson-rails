# frozen_string_literal: true

# s01e12 — Вопрос, которого нет
#
#   cp starter.rb artifacts/dynamic.rb
#   make test

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

    # TODO: вторая половина дела. Без неё respond_to? врёт, а
    #       method(:find_by_road) не работает — Ruby спрашивает именно этот
    #       метод, а не respond_to?.
    # TODO: не забудь super для всех прочих имён.

    private

    # TODO: разобрать имя. Не наше — отдать дальше по цепочке (super).
    #       Без super опечатка в имени превратится в nil и станет невидимой.
    # TODO: ровно один аргумент; иначе ArgumentError с именем метода.
    # TODO: find_by_* возвращает записи, count_by_* — их число.
    def method_missing(name, *args, &block)
    end
  end
end
