# Телеграммы конторы: написать, отдать, посмотреть, что с ними.
#
# Контора не ждёт у аппарата.
class TelegramsController < ApplicationController
  def index
    @telegrams = Telegram.order(created_at: :desc, id: :desc)
  end

  def show
    @telegram = Telegram.find(params[:id])
  end

  def new
    @telegram = Telegram.new
  end

  def create
    # TODO: записать телеграмму в книгу.
    #       Принята — записка работнику (DispatchJob) и 303 на её страницу.
    #       Не принята — тот же бланк с причинами и 422 (s05e04).
    #       На линию отсюда не ходить.
  end

  private

  def telegram_params
    params.expect(telegram: %i[addressee body])
  end
end
