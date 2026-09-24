# Выплата по расчёту.
#
# Отвечает двумя способами, по тому, что спрашивающий готов принять. Turbo
# просит поток первым — и получает три действия: заменить строку расчёта,
# дописать запись в журнал подтверждений, сказать о сделанном в живую
# область. Кто потока не понимает — получает то, что получал бы всегда: 303 на
# лист расчётов.
#
# Оплата — `pay!` из s04e09: под блокировкой и ровно один раз.
class PaymentsController < ApplicationController
  before_action :set_settlement

  def create
    @settlement.pay!

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to company_settlements_path(@company), status: :see_other,
                    notice: "Расчёт #{@settlement.period} с #{@company.code} оплачен."
      end
    end
  rescue Settlement::AlreadyPaid => error
    # Страница, с которой нажали, устарела: расчёт уже оплачен — из соседнего
    # окна или минуту назад. Отказ — 422, и поток приносит на страницу правду:
    # строку в том виде, в каком она есть, и причину.
    #
    # Перечитывать строку не нужно: `pay!` уже перечитал её под блокировкой
    # (`with_lock`, s04e09), и в `@settlement` — то, что в базе сейчас.
    @refusal = error.message

    respond_to do |format|
      format.turbo_stream { render :refused, status: :unprocessable_content }
      format.html do
        @settlements = @company.settlements.order(:period)
        flash.now[:alert] = @refusal
        render "settlements/index", status: :unprocessable_content
      end
    end
  end

  private

  # Расчёт — в пределах дороги, как бланк в s05e06: расчёт другой дороги
  # через этот адрес не найдётся.
  def set_settlement
    @company = Company.find_by!(code: params[:company_code])
    @settlement = @company.settlements.find_by!(period: params[:settlement_period])
  end
end
