# Помощники страниц с расчётами.
module SettlementsHelper
  STATES = { "pending" => "посчитан", "paid" => "оплачен" }.freeze

  # Состояние словом. `enum` хранит имена для кода — `pending`, `paid`; вслух
  # их не читают.
  def settlement_state(settlement) = STATES.fetch(settlement.state)
end
