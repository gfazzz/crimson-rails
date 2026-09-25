# Переплата казны: выплата по книге казначейства сверх одной на поставку.
class Overpayment < ApplicationRecord
  belongs_to :delivery
end
