require "net/http"

# Линия Большого Северного телеграфного общества — со стороны конторы.
#
# Линия принимает телеграмму и отвечает номером, под которым её передаст.
# Адрес линии — в настройках приложения (`config.x.telegraph_line`): в
# конторе это станция на Светланской, в проверках — поддельная линия,
# которую поднимает сама проверка.
#
# Линия отвечает не только номером. Ответ делится на три исхода, и у
# каждого своё исключение: от него зависит, что сделает задача (s06e03).
#
#   принято               — номер линии
#   линия лежит (5xx, нет соединения) — Down: пройдёт, стоит повторить позже
#   отказ (4xx)           — Rejected: не пройдёт никогда, повторять незачем
#
# И линия может молчать: не взять трубку или взять и не ответить. Ждать её
# вечно нельзя — работник один на весь телеграф (s06e02). Молчание дольше
# предела — тот же обрыв (s06e05).
#
# Линия принимает телеграмму и не отвечает — такое тоже бывает: передала, а
# ответ потерялся. Повтор тогда подаст телеграмму второй раз. Чтобы линия
# узнала повтор, каждая подача несёт наш номер отправления — заголовок
# `Idempotency-Key`: с тем же ключом линия второй раз не передаёт и отвечает
# прежним номером.
module TelegraphLine
  class Error < StandardError; end

  # Линия лежит: обрыв, перегрузка, станция закрыта на ремонт.
  class Down < Error; end

  # Линия отказала: адресата нет, текст не принят. Сколько ни повторяй —
  # ответ будет тот же.
  class Rejected < Error; end

  # Станция на Светланской принимает телеграммы с 8 утра до 8 вечера по
  # владивостокскому времени. Ночью окошко закрыто.
  OPENS = 8
  CLOSES = 20

  # Сколько ждать станцию. Соединение — секунда: станция через улицу.
  # Ответ — две: дольше линия не думает, если жива.
  OPEN_TIMEOUT = 1
  READ_TIMEOUT = 2

  module_function

  def url = URI(Rails.configuration.x.telegraph_line)

  # Когда станция примет телеграмму, поданную в `time`: в часы окошка —
  # сразу, до открытия — в восемь того же дня, после закрытия — в восемь
  # следующего. Часы — владивостокские (config.time_zone).
  def opens_at(time)
    time = time.in_time_zone
    opening = time.change(hour: OPENS)
    return opening if time < opening
    return time if time.hour < CLOSES

    opening + 1.day
  end

  # Подать телеграмму. Возвращает номер линии.
  def deliver(telegram)
    response = request(Net::HTTP::Post.new("/messages").tap do |post|
      post["Content-Type"] = "application/json"
      post["Idempotency-Key"] = telegram.key
      post.body = { to: telegram.addressee, body: telegram.body }.to_json
    end)

    case response
    when Net::HTTPSuccess then JSON.parse(response.body).fetch("number")
    when Net::HTTPServerError then raise Down, "линия лежит: #{response.code}"
    else raise Rejected, "линия отказала: #{reason(response)}"
    end
  end

  # Справка о телеграмме по номеру линии: что с ней, если это телеграмма
  # этой линии, и nil, если линия такой не знает. «Не знаю» — ответ, а не
  # ошибка.
  def trace(number)
    response = request(Net::HTTP::Get.new("/messages/#{ERB::Util.url_encode(number)}"))

    case response
    when Net::HTTPSuccess then JSON.parse(response.body)
    when Net::HTTPNotFound then nil
    when Net::HTTPServerError then raise Down, "линия лежит: #{response.code}"
    else raise Rejected, "линия отказала: #{reason(response)}"
    end
  end

  # Один запрос к станции — с пределами ожидания. Всё, что значит «станция
  # не ответила», — обрыв.
  #
  # `max_retries: 0`: Net::HTTP сам, молча, повторяет GET один раз после
  # обрыва или молчания. Повторять здесь решает задача (s06e03) — с паузой и
  # пределом; второй, невидимый повтор внутри первого ей только мешает.
  def request(message)
    Net::HTTP.start(url.host, url.port, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
                                        write_timeout: READ_TIMEOUT, max_retries: 0) do |http|
      http.request(message)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => error
    raise Down, "станция молчит: #{error.class}"
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, SocketError => error
    raise Down, "нет связи со станцией: #{error.class}"
  end

  # Причина отказа словами линии, если она её назвала.
  def reason(response)
    JSON.parse(response.body.to_s).fetch("error", response.code)
  rescue JSON::ParserError
    response.code
  end
end
