# Выплатить казной по квитанции о приёмке.
#
# Очередь обещает «хотя бы раз»: записку исполнят дважды, если работник
# умрёт после выплаты, но до отметки; если квитанцию на ту же поставку
# пришлют ещё раз; если два работника возьмут две записки одновременно.
# Задача обязана дать один эффект на любое число исполнений.
#
# Эффектов два: выплата в книге казны и телеграмма казначейству о ней. Оба —
# в одной транзакции: телеграмма — это строка в книге и записка в очереди, а
# очередь лежит в той же базе (s06e01). Либо оба, либо ни одного.
class DisburseJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(acceptance)
    delivery = acceptance.delivery

    Disbursement.transaction do
      disbursement = Disbursement.create_or_find_by!(delivery: delivery) do |fresh|
        fresh.acceptance = acceptance
        fresh.kopecks = delivery.kopecks
        fresh.paid_at = Time.current
      end

      # Выплата уже была — этой квитанцией или другой. Второй раз не
      # платим и второй раз не сообщаем.
      next unless disbursement.previously_new_record?

      notice = Telegram.create!(
        delivery: delivery,
        addressee: "Казначейство постройки, Владивосток",
        body: "ВЫПЛАЧЕНО #{delivery.reference} #{delivery.kopecks / 100} РУБ #{delivery.kopecks % 100} КОП"
      )
      DispatchJob.hand_in(notice)
    end
  end
end
