require "csv"

# Лист расчётов дороги.
#
# Отдельный адрес — не ради красоты. Страница дороги вклеивает этот лист
# фреймом и не ждёт, пока он посчитается; а сам по себе лист — полная
# страница, которую можно открыть ссылкой, без Turbo и без страницы дороги.
#
# И три вида одного и того же листа, по тому, кто спрашивает: страница — для
# человека; JSON — для телеграфного аппарата, который читает реестр сам;
# CSV — для кассы, которая сверяет его в своих книгах. Что спрашивающий готов
# принять, он говорит сам: расширением адреса или заголовком `Accept`. Чего не
# готов — 406.
class SettlementsController < ApplicationController
  def index
    @company = Company.find_by!(code: params[:company_code])
    @settlements = @company.settlements.order(:period)

    respond_to do |format|
      format.html
      format.json
      format.csv do
        send_data csv, type: :csv, disposition: "attachment",
                       filename: "#{@company.code}-settlements.csv"
      end
    end
  end

  private

  # Пенсы — целым числом, как в реестре (s04e02); чтение фунтами — рядом,
  # для глаз. Машине читать нечего, ей нужно число.
  def csv
    CSV.generate do |rows|
      rows << %w[period pence reading state]
      @settlements.each do |settlement|
        rows << [settlement.period, settlement.pence, helpers.money(settlement.pence),
                 helpers.settlement_state(settlement)]
      end
    end
  end
end
