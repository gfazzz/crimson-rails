# Квитанции, которые линия шлёт конторе сама.
#
# Линия шлёт JSON:
#
#   { "number": "НГС-7712", "route": "cable", "delivery": "NGS-0512",
#     "signed_by": "Кувабара", "accepted_on": "1892-06-16" }
#
# и два заголовка: `X-Line-Timestamp` — секунды Unix, когда подписано;
# `X-Line-Signature` — HMAC-SHA256 общего секрета
# (`Rails.configuration.x.line_secret`) над строкой «время.тело», в
# шестнадцатеричном виде.
class ReceiptsController < ApplicationController
  # TODO: у линии нет токена нашей формы.

  # TODO: подпись неверна, её нет или ей больше пяти минут — 401, и ничего
  #       не записано.

  def create
    # TODO: принято — квитанция в книге (Acceptance.receive!), 202, JSON.
    #       Поставки нет, тело не JSON, квитанция не проходит — 422, JSON.
    #       Выплату делает работник, а не этот запрос.
  end
end
