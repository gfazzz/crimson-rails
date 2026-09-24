# Реестр дорог — первое, что конторе нужно без письма в Лондон.
#
# Одно действие — одно решение. Контроллер не считает и не проверяет: он
# находит, что просили, и отдаёт представлению.
class CompaniesController < ApplicationController
  # Найти дорогу — одно решение, и принимается оно в одном месте.
  before_action :set_company, only: :show

  # Список. По коду: так дороги стоят в книгах Палаты, и так их ищут глазами.
  #
  # Пустой реестр — тоже ответ: 200 и пустой список, а не ошибка.
  def index
    @companies = Company.order(:code)
  end

  # Одна дорога и её расчёты, по месяцам. Порядок решает контроллер, а не
  # шаблон: шаблон показывает, что ему дали.
  def show
    @settlements = @company.settlements.order(:period)
  end

  private

  # `find_by!` — тот же `find`, только по другому столбцу: нет дороги —
  # RecordNotFound — 404.
  def set_company
    @company = Company.find_by!(code: params[:code])
  end
end
