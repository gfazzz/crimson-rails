# Сводка конторы за день — к восьми утра, по расписанию (config/recurring.yml).
#
# День — владивостокский и по новому стилю. «Вчера» в восемь утра во
# Владивостоке — это вчера во Владивостоке, а не вчера в Гринвиче: там ещё
# позавчерашний вечер. Квитанции приходят датированными в двух календарях
# (Acceptance#accepted_day) и сводятся к одному.
#
# «Вчера» — от того, когда записку поставили, а не когда её исполнили:
# работник, пролежавший до полуночи, всё равно сведёт вчерашний день
# расписания, а не сегодняшний.
#
# Сводку можно поставить дважды — и она ляжет одна: день — ключ, повторный
# счёт заменяет числа, а не добавляет строку.
class DailyReportJob < ApplicationJob
  def perform(day = nil)
    day = day ? Date.parse(day.to_s) : (enqueued_at || Time.current).in_time_zone.to_date.yesterday
    window = Time.zone.local(day.year, day.month, day.day).all_day

    # Бланки старого стиля за этот день датированы на двенадцать дней
    # раньше, поэтому смотреть надо с запасом и отбирать по дню приёмки.
    candidates = Acceptance.where(accepted_on: (day - 13)..day)
    receipts = candidates.select { |receipt| receipt.accepted_day == day }

    DayReport.upsert(
      { day: day,
        arrived: Delivery.where(arrived_on: day).count,
        receipts: receipts.size,
        repeats: receipts.group_by(&:delivery_id).count { |_, group| group.size > 1 },
        paid_kopecks: Disbursement.where(paid_at: window).sum(:kopecks),
        created_at: Time.current, updated_at: Time.current },
      unique_by: :day, update_only: %i[arrived receipts repeats paid_kopecks updated_at]
    )
  end
end
