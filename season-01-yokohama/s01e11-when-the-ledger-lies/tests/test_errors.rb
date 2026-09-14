# frozen_string_literal: true
#
# CRIMSON RAILS — s01e11, проверка.

require "minitest/autorun"

ART = File.expand_path("../artifacts/errors.rb", __dir__)
SOL = File.expand_path("../solution/errors.rb", __dir__)
source = (File.exist?(ART) && ENV["FORCE_SOLUTION"].nil?) ? ART : SOL
puts "Источник: #{source.sub(File.expand_path("../..", __dir__) + "/", "")}"
puts "(артефакта нет — проверяю эталон)" if source == SOL && !File.exist?(ART)
require source

ROW = { road: "SJI", cargo: "чай", weight: 800, charge: 40 }.freeze

# Телеграфный источник: падает заданное число раз, потом отдаёт ведомость.
class FlakySource
  attr_reader :fetches, :closes

  def initialize(rows: [ROW], fail_times: 0, error: Abacus::TransmissionError)
    @rows = rows
    @fail_times = fail_times
    @error = error
    @fetches = 0
    @closes = 0
  end

  def fetch
    @fetches += 1
    raise @error, "линия оборвалась" if @fetches <= @fail_times

    @rows
  end

  def close = @closes += 1
end

class TestHierarchy < Minitest::Test
  def test_всё_наследуется_от_StandardError_а_не_от_Exception
    [Abacus::Error, Abacus::LedgerError, Abacus::MalformedRow,
     Abacus::UnknownRoad, Abacus::TransmissionError].each do |klass|
      assert_operator klass, :<, StandardError,
                      "#{klass} должен быть ветвью StandardError: обычный rescue " \
                      "ловит именно её, а Exception — это про прерывания и выход."
    end
  end

  def test_один_корень_на_всё_приложение
    assert_operator Abacus::LedgerError, :<, Abacus::Error
    assert_operator Abacus::MalformedRow, :<, Abacus::LedgerError
    assert_operator Abacus::UnknownRoad, :<, Abacus::LedgerError
    assert_operator Abacus::TransmissionError, :<, Abacus::Error
  end

  def test_беда_ведомости_и_беда_связи_это_разные_ветки
    refute_operator Abacus::TransmissionError, :<, Abacus::LedgerError,
                    "Их лечат по-разному: одну повторяют, другую разбирают."
  end

  def test_можно_поймать_всё_одним_rescue
    caught = begin
      raise Abacus::MalformedRow.new("проба", line: 7)
    rescue Abacus::Error => e
      e
    end
    assert_kind_of Abacus::MalformedRow, caught
  end
end

class TestErrorCarriesContext < Minitest::Test
  def test_ошибка_несёт_номер_строки
    error = Abacus::MalformedRow.new("нет кода дороги", line: 388)
    assert_equal 388, error.line, "Ошибка без адреса — половина ошибки."
  end

  def test_номер_строки_виден_в_сообщении
    error = Abacus::MalformedRow.new("нет кода дороги", line: 388)
    assert_includes error.message, "388"
    assert_includes error.message, "нет кода дороги"
  end

  def test_без_номера_сообщение_не_ломается
    error = Abacus::MalformedRow.new("нет кода дороги")
    assert_nil error.line
    assert_includes error.message, "нет кода дороги"
  end

  def test_сообщение_по_умолчанию_есть
    refute_empty Abacus::LedgerError.new.message
  end
end

class TestRetry < Minitest::Test
  def test_временная_беда_повторяется_и_проходит
    source = FlakySource.new(fail_times: 2)
    loader = Abacus::Loader.new(source)

    assert_equal [ROW], loader.load
    assert_equal 3, source.fetches, "Две неудачи и одна удача — три обращения."
    assert_equal 3, loader.attempts
  end

  def test_повторы_не_бесконечны
    source = FlakySource.new(fail_times: 99)
    loader = Abacus::Loader.new(source)

    assert_raises(Abacus::TransmissionError) { loader.load }
    assert_equal Abacus::Loader::MAX_ATTEMPTS, source.fetches,
                 "Повтор без предела — это не устойчивость, а вечный цикл."
  end

  def test_беда_ведомости_не_повторяется
    source = FlakySource.new(rows: ["не запись"])
    loader = Abacus::Loader.new(source)

    assert_raises(Abacus::MalformedRow) { loader.load }
    assert_equal 1, source.fetches,
                 "Повторять разбор битой строки бессмысленно: второй раз выйдет то же."
  end

  def test_счётчик_попыток_обнуляется_между_загрузками
    source = FlakySource.new(fail_times: 1)
    loader = Abacus::Loader.new(source)
    loader.load
    assert_equal 2, loader.attempts

    fresh = Abacus::Loader.new(FlakySource.new)
    assert_equal 1, fresh.load && fresh.attempts
  end
end

class TestEnsure < Minitest::Test
  def test_источник_закрывается_при_удаче
    source = FlakySource.new
    Abacus::Loader.new(source).load
    assert_equal 1, source.closes
  end

  def test_источник_закрывается_при_ошибке_разбора
    source = FlakySource.new(rows: ["не запись"])
    assert_raises(Abacus::MalformedRow) { Abacus::Loader.new(source).load }
    assert_equal 1, source.closes, "ensure выполняется и когда всё пошло не так."
  end

  def test_источник_закрывается_после_исчерпания_повторов
    source = FlakySource.new(fail_times: 99)
    assert_raises(Abacus::TransmissionError) { Abacus::Loader.new(source).load }
    assert_equal 1, source.closes,
                 "Закрыть нужно один раз, а не по разу на каждую попытку."
  end

  def test_ensure_не_проглатывает_исключение
    source = FlakySource.new(rows: ["не запись"])
    error = assert_raises(Abacus::MalformedRow) { Abacus::Loader.new(source).load }
    assert_kind_of Abacus::MalformedRow, error,
                   "Если в ensure стоит return или свой raise, исходная ошибка " \
                   "исчезнет, и причину будет не найти."
  end
end

class TestParsing < Minitest::Test
  def test_строка_без_кода_дороги
    source = FlakySource.new(rows: [ROW, { cargo: "чай" }])
    error = assert_raises(Abacus::MalformedRow) { Abacus::Loader.new(source).load }
    assert_equal 2, error.line, "Номер строки — вторая: нумерация с единицы."
  end

  def test_дорога_вне_реестра
    source = FlakySource.new(rows: [ROW.merge(road: "SJX")])
    loader = Abacus::Loader.new(source, known_roads: %w[NTK SJI])
    error = assert_raises(Abacus::UnknownRoad) { loader.load }
    assert_includes error.message, "SJX"
    assert_equal 1, error.line
  end

  def test_без_реестра_дороги_не_проверяются
    source = FlakySource.new(rows: [ROW.merge(road: "SJX")])
    assert_equal 1, Abacus::Loader.new(source).load.size
  end
end
