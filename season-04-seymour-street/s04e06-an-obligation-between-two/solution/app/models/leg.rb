# Участок пути: часть перевозки, пройденная одной дорогой.
class Leg < ApplicationRecord
  belongs_to :consignment
  belongs_to :company

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :miles, numericality: { only_integer: true, greater_than: 0 }

  # Вежливость к составному индексу: сказать «эта позиция в перевозке уже
  # занята» раньше, чем откажет база. `scope:` — это и есть «в пределах».
  validates :position, uniqueness: { scope: :consignment_id }
end
