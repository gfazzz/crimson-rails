# Выплата казны по квитанции о приёмке.
class Disbursement < ApplicationRecord
  # TODO: выплата — тоже.
  belongs_to :delivery
  belongs_to :acceptance

  validates :kopecks, numericality: { only_integer: true, greater_than: 0 }
  validates :paid_at, presence: true
end
