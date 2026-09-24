# Телеграммы конторы: написать, отдать, посмотреть, что с ними.
#
# Контора не ждёт у аппарата. Принять телеграмму — значит записать её в книгу
# и оставить записку работнику; ответ конторе — сразу, 303 на страницу
# телеграммы. Что скажет линия, будет видно там, когда работник дойдёт.
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
    @telegram = Telegram.new(telegram_params)

    if @telegram.save
      # TODO: не прямо в очередь, а через DispatchJob.hand_in — он знает часы станции.
      DispatchJob.perform_later(@telegram)
      redirect_to @telegram, status: :see_other, notice: "Телеграмма в очереди на линию."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def telegram_params
    params.expect(telegram: %i[addressee body])
  end
end
