# Квитанции, которые линия шлёт конторе сама.
#
# Это не форма и не человек: это чужая система, которая стучится к нам. Ей
# нужно три вещи — узнать, что её услышали; не ждать, пока контора сделает
# работу; и не получить второй эффект, если постучится дважды. Нам — одна:
# убедиться, что стучится именно она.
#
#   подпись неверна или устарела    — 401, ничего не записано
#   поставки такой нет              — 422, линия повторит позже
#   принято                         — 202: записано, выплата — работнику
#   та же квитанция второй раз      — 202, вторая строка не заводится
class ReceiptsController < ApplicationController
  # У линии нет нашей формы и нашего токена формы. Подлинность здесь
  # доказывает подпись, а не токен.
  skip_forgery_protection

  # Подпись старше пяти минут — не принимаем: перехваченную квитанцию нельзя
  # прислать снова через месяц.
  FRESH = 5.minutes

  before_action :verify_signature

  def create
    receipt = JSON.parse(request.raw_post)
    delivery = Delivery.find_by(reference: receipt["delivery"])
    return render(json: { error: "unknown_delivery" }, status: :unprocessable_content) unless delivery

    Acceptance.receive!(delivery: delivery, route: receipt["route"], line_number: receipt["number"],
                        signed_by: receipt["signed_by"], accepted_on: receipt["accepted_on"])
    render json: { status: "accepted" }, status: :accepted
  rescue JSON::ParserError, ActiveRecord::RecordInvalid => error
    render json: { error: "bad_receipt", message: error.message }, status: :unprocessable_content
  end

  private

  # Подпись — HMAC-SHA256 общего секрета над «время.тело»: сырое тело, как
  # оно пришло, а не то, что Rails из него разобрал.
  def verify_signature
    stamp = request.headers["X-Line-Timestamp"].to_s
    given = request.headers["X-Line-Signature"].to_s
    expected = OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.line_secret, "#{stamp}.#{request.raw_post}")

    # Время — секунды Unix. До 1970 года они отрицательны, и в 1892-м тоже.
    fresh = stamp.match?(/\A-?\d+\z/) && (Time.current.to_i - stamp.to_i).abs <= FRESH
    return if fresh && ActiveSupport::SecurityUtils.secure_compare(given, expected)

    render json: { error: "bad_signature" }, status: :unauthorized
  end
end
