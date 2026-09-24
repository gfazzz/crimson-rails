# Бланки из Дерби — прямо в реестр.
#
# У формы два исхода, и у каждого свой код. Принято — 303 и адрес, где
# смотреть: браузер сам перейдёт туда запросом GET, и повторное нажатие
# «обновить» не внесёт бланк второй раз. Не принято — 422 и та же форма с
# причинами: запрос понят, но принять его нельзя.
#
# Turbo на этих кодах держится: форму, ответившую 200, он не покажет вовсе.
class ConsignmentsController < ApplicationController
  before_action :set_roads, only: %i[new create]

  # Пустой бланк. Если пришли со страницы дороги, дорога-отправитель уже
  # выбрана.
  def new
    @consignment = Consignment.new(company: Company.find_by(code: params[:company]))
  end

  def create
    @consignment = Consignment.new(consignment_params)

    if @consignment.save
      redirect_to company_path(@consignment.company), status: :see_other,
                  notice: "Бланк #{@consignment.reference} внесён в реестр."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    # Валидация посмотрела и не нашла; между её взглядом и записью бланк с тем
    # же номером успел лечь. Отказал индекс (s04e04) — и отказ обязан дойти до
    # кассира словами, а не страницей 500.
    @consignment.errors.add(:reference, :taken)
    render :new, status: :unprocessable_content
  end

  private

  # Что форма вправе прислать — и больше ничего. Отметку о расчёте ставит
  # счёт за месяц (s04e09), а не тот, кто вносит бланк; поле `settled`,
  # дописанное в запрос руками, будет выброшено.
  #
  # `expect`: нет бланка в запросе, или пришёл не бланк — 400, а не 500.
  def consignment_params
    params.expect(consignment: %i[company_id reference description sent_on pence weight_lb])
  end

  def set_roads
    @roads = Company.order(:code)
  end
end
