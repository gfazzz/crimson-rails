# frozen_string_literal: true

module Abacus
  # Корень иерархии. Наследуемся от StandardError, а не от Exception:
  # обычный rescue ловит именно StandardError, и ошибки приложения обязаны
  # быть в этой ветке.
  class Error < StandardError; end

  # Беда в самой ведомости. Несёт номер строки: ошибка без адреса —
  # половина ошибки.
  class LedgerError < Error
    attr_reader :line

    def initialize(message = "ведомость не разобрана", line: nil)
      @line = line
      super(line ? "#{message} (строка #{line})" : message)
    end
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

    def load
      @attempts = 0
      begin
        @attempts += 1
        rows = @source.fetch
        rows.each_with_index.map { |row, index| parse(row, line: index + 1) }
      rescue TransmissionError
        # Повторяем только временную беду и только ограниченное число раз.
        retry if @attempts < MAX_ATTEMPTS

        raise
      ensure
        # Выполняется всегда: и при удаче, и при любой ошибке.
        # Ни return, ни собственного raise здесь быть не должно —
        # они проглотят исходное исключение.
        @source.close
      end
    end

    private

    def parse(row, line:)
      raise MalformedRow.new("строка не является записью", line: line) unless row.is_a?(Hash)

      road = row[:road]
      raise MalformedRow.new("нет кода дороги", line: line) if road.nil?

      if @known_roads && !@known_roads.include?(road)
        raise UnknownRoad.new("дорога #{road.inspect} не в реестре", line: line)
      end

      row
    end
  end
end
