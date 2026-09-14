# frozen_string_literal: true

# s01e11 — Когда ведомость врёт
#
#   cp starter.rb artifacts/errors.rb
#   make test

module Abacus
  # Корень иерархии. Наследуемся от StandardError, а не от Exception:
  # обычный rescue ловит именно StandardError, и ошибки приложения обязаны
  # быть в этой ветке.
  class Error < StandardError; end

  # Беда в самой ведомости. Несёт номер строки: ошибка без адреса —
  # половина ошибки.
  class LedgerError < Error
    # TODO: ошибка должна нести номер строки и читаться отдельно (attr_reader),
    #       и попадать в текст сообщения, если он задан.
    # TODO: не забудь про super — сообщение хранит сам StandardError.
  end

  # Строку не разобрать.
  class MalformedRow < LedgerError; end

  # Дороги нет в реестре.
  class UnknownRoad < LedgerError; end

  # Беда в передаче. Отличается от прочих тем, что имеет смысл повторить.
  class TransmissionError < Error; end

  # Загрузка ведомости из источника.
  #
  # Источник — любой объект с методами fetch и close.
  class Loader
    MAX_ATTEMPTS = 3

    attr_reader :attempts

    def initialize(source, known_roads: nil)
      @source = source
      @known_roads = known_roads
      @attempts = 0
    end

    # TODO: считать попытки в @attempts (тест их проверяет).
    # TODO: повторять ТОЛЬКО TransmissionError и не больше MAX_ATTEMPTS раз,
    #       после чего отдать ошибку наружу как есть.
    # TODO: беды самой ведомости не повторять — их повтор ничего не изменит.
    # TODO: источник закрывать всегда: и при удаче, и при любой ошибке.
    #       Ни return, ни своего raise в этом месте быть не должно.
    def load
    end

    private

    # TODO: не хеш — MalformedRow; нет кода дороги — MalformedRow;
    #       дорога не из списка known_roads — UnknownRoad.
    # TODO: в каждой ошибке — номер строки.
    def parse(row, line:)
    end
  end
end
