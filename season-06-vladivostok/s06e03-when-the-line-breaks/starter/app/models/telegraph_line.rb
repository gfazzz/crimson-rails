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
# Как линия молчит — предмет s06e05.
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
    response = Net::HTTP.post(
      URI.join(url, "/messages"),
      { to: telegram.addressee, body: telegram.body }.to_json,
      "Content-Type" => "application/json"
    )
    # TODO: 2xx — номер; 5xx — Down; прочее — Rejected, с причиной, которую
    #       назвала линия (поле "error" в ответе).
    # TODO: нет соединения со станцией — тоже Down.
    raise Error, "линия ответила #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("number")
  end
end
