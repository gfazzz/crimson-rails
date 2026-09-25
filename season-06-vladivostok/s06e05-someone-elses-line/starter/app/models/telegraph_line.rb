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
# И линия может молчать: не взять трубку или взять и не ответить. И может
# принять телеграмму и потерять ответ (s06e05).
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

  # TODO: сколько ждать станцию — соединения и ответа. Работник у телеграфа
  #       один: пока он ждёт, не уходит ни одна телеграмма.

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
  #
  # TODO: молчание станции дольше предела — обрыв (Down).
  # TODO: каждая подача несёт номер отправления телеграммы — заголовок
  #       `Idempotency-Key`: по нему линия узнаёт повтор и не передаёт его.
  def deliver(telegram)
    response = Net::HTTP.post(
      URI.join(url, "/messages"),
      { to: telegram.addressee, body: telegram.body }.to_json,
      "Content-Type" => "application/json"
    )

    case response
    when Net::HTTPSuccess then JSON.parse(response.body).fetch("number")
    when Net::HTTPServerError then raise Down, "линия лежит: #{response.code}"
    else raise Rejected, "линия отказала: #{reason(response)}"
    end
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, SocketError => error
    raise Down, "нет связи со станцией: #{error.class}"
  end

  # Справка о телеграмме по номеру линии: `GET /messages/<номер>`.
  #
  # TODO: `TelegraphLine.trace(number)`. 200 — что линия ответила (хеш);
  #       404 — nil: «не наша» — ответ, а не ошибка; 5xx и молчание — Down.
  #       С теми же пределами ожидания.

  # Причина отказа словами линии, если она её назвала.
  def reason(response)
    JSON.parse(response.body.to_s).fetch("error", response.code)
  rescue JSON::ParserError
    response.code
  end
end
