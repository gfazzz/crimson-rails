# Сводка конторы за день — к восьми утра, по расписанию (config/recurring.yml).
#
#   DailyReportJob.perform_later             — за вчера
#   DailyReportJob.perform_later("1892-07-23") — за этот день
#
# DayReport: день, пароходов у причала, квитанций за день, повторов
# (поставок, у которых за день больше одной квитанции), выплачено казной.
class DailyReportJob < ApplicationJob
  def perform(day = nil)
    # TODO: «вчера» — во Владивостоке, и от того, когда записку поставили.
    # TODO: квитанции за день — по дню приёмки в одном календаре
    #       (Acceptance#accepted_day).
    # TODO: поставленная дважды, сводка ложится одна — со свежими числами.
  end
end
