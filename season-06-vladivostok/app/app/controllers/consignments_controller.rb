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
  before_action :set_company, only: %i[index show]

  # Книга перевозок дороги: только её бланки, по дате.
  def index
    @consignments = @company.consignments.order(:sent_on, :reference)
  end

  # Одна перевозка — через книгу своей дороги.
  #
  # Ищут в `@company.consignments`, а не в `Consignment`: бланк другой дороги
  # здесь не найдётся — RecordNotFound — 404, — даже если в реестре он есть.
  # `Consignment.find_by!` открыл бы любой бланк через любую книгу: листы
  # одной дороги оказались бы подшиты в книгу другой.
  #
  # Участки — вместе с дорогами, одним запросом (s04e07): страница перевозки
  # спрашивает базу одинаковое число раз, сколько бы участков ни было.
  def show
    @consignment = @company.consignments.find_by!(reference: params[:reference])
    @legs = @consignment.legs.includes(:company)
  end

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

  def set_company
    @company = Company.find_by!(code: params[:company_code])
  end
end
