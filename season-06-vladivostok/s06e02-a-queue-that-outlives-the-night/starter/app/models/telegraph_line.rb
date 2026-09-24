require "net/http"

# Линия Большого Северного телеграфного общества — со стороны конторы.
#
# Линия принимает телеграмму и отвечает номером, под которым её передаст.
# Адрес линии — в настройках приложения (`config.x.telegraph_line`): в
# конторе это станция на Светланской, в проверках — поддельная линия,
# которую поднимает сама проверка.
#
# Этот вариант — первый и наивный: он умеет только счастливый путь. Как линия
# рвётся, отвечает отказом и молчит — предмет s06e03 и s06e05.
module TelegraphLine
  class Error < StandardError; end

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
    # TODO
    time
  end

  # Подать телеграмму. Возвращает номер линии.
  def deliver(telegram)
    response = Net::HTTP.post(
      URI.join(url, "/messages"),
      { to: telegram.addressee, body: telegram.body }.to_json,
      "Content-Type" => "application/json"
    )
    raise Error, "линия ответила #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("number")
  end
end
