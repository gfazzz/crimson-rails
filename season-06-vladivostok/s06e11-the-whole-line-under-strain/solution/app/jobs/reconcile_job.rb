# Сверка книги выплат конторы с книгой казначейства за месяц.
#
# Казна платит по квитанции (s06e04). Контора — по поставке. Всё, что казна
# выплатила за поставку сверх одного раза, — переплата. Какая из выплат
# «своя»: та, что по той же квитанции, по которой выплатила контора; если
# контора ещё не платила — первая по книге казначейства.
#
# Сверку ставит расписание (config/recurring.yml) первого числа за прошлый
# месяц, её ставят руками, её повторяют после обрыва. Переплата с тем же
# ключом — поставка и квитанция казначейства — ложится одна.
class ReconcileJob < ApplicationJob
  retry_on TreasuryBook::Down, wait: :polynomially_longer, attempts: 5

  def perform(month = nil)
    month ||= (enqueued_at || Time.current).in_time_zone.to_date.prev_month.strftime("%Y-%m")
    rows = TreasuryBook.payments(month)
    deliveries = Delivery.where(reference: rows.map { |row| row["delivery"] }.uniq).index_by(&:reference)

    overpaid = rows.group_by { |row| row["delivery"] }.flat_map do |reference, paid|
      delivery = deliveries[reference]
      next [] unless delivery && paid.size > 1

      ours = delivery.disbursements.first&.acceptance&.line_number
      kept = paid.find { |row| row["receipt"] == ours } || paid.first
      (paid - [kept]).map do |row|
        { delivery_id: delivery.id, receipt: row["receipt"], month: month, kopecks: row["kopecks"],
          created_at: Time.current, updated_at: Time.current }
      end
    end

    Overpayment.upsert_all(overpaid, unique_by: %i[delivery_id receipt]) if overpaid.any?
  end
end
