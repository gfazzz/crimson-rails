# Лист выплат казны за месяц.
#
# Лист читают издалека — казначейство по проводу, Лондон кабелем — и читают
# часто, а меняется он редко. Каждое чтение целиком — это лист, переданный
# заново, слово за словом. Поэтому ответ несёт свою версию (`ETag`) и время
# последней правки (`Last-Modified`), и тот, у кого лист уже есть, спрашивает:
# «а у меня — не этот?». Если этот — 304 и пустое тело: лист у тебя уже
# есть.
class PayoutsController < ApplicationController
  def show
    @month = params[:month]
    window = Time.zone.parse("#{@month}-01").all_month
    @disbursements = Disbursement.where(paid_at: window).includes(:delivery, :acceptance).order(:paid_at, :id)

    # Версия листа — месяц и версия выборки: число выплат и последняя
    # правка (s06e07). Последняя правка — для тех, кто спрашивает по времени.
    # Пустой лист тоже лист: его версия — месяц без выплат.
    #
    # Хранить лист у себя можно, пользоваться им не спросив — нельзя:
    # `fresh_when` ставит `max-age=0, private, must-revalidate`. Без этого
    # (например, с одним `public`) читающий вправе сам решить, что лист
    # ещё свежий, — по тому, как давно его правили.
    fresh_when etag: [@month, @disbursements.cache_key_with_version],
               last_modified: @disbursements.maximum(:updated_at) || window.first
  end
end
