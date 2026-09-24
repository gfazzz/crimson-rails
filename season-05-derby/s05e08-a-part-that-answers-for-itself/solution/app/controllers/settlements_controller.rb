# Лист расчётов дороги.
#
# Отдельный адрес — не ради красоты. Страница дороги вклеивает этот лист
# фреймом и не ждёт, пока он посчитается; а сам по себе лист — полная
# страница, которую можно открыть ссылкой, без Turbo и без страницы дороги.
class SettlementsController < ApplicationController
  def index
    @company = Company.find_by!(code: params[:company_code])
    @settlements = @company.settlements.order(:period)
  end
end
