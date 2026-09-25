# Сводка конторы за день.
class DayReport < ApplicationRecord
  validates :day, presence: true
end
