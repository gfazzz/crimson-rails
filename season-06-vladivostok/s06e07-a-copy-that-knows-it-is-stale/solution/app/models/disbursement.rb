# Выплата казны по квитанции о приёмке.
class Disbursement < ApplicationRecord
  # Выплата меняет поставку: «оплачено» — на её строке в списке (s06e07).
  belongs_to :delivery, touch: true
  belongs_to :acceptance

  validates :kopecks, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_at, presence: true
end
