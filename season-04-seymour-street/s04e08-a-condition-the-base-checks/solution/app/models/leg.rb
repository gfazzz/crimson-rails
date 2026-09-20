# Участок пути: часть перевозки, пройденная одной дорогой.
class Leg < ApplicationRecord
  belongs_to :consignment
  belongs_to :company

  # Имена трём числам. `enum` даёт отборы (`Leg.collected`), вопросы
  # (`leg.hauled?`) и переходы (`leg.delivered!`) — и **не** даёт гарантии:
  # строка с role = 7 приедет мимо модели и сломает всякий разбор по ролям.
  # Гарантию даёт `CHECK` в схеме.
  enum :role, { collected: 0, hauled: 1, delivered: 2 }

  # Принявший участок в перевозке один. Вежливость к частичному индексу:
  # `conditions:` сужает проверку так же, как `where:` сужает индекс.
  validates :role, uniqueness: { scope: :consignment_id, conditions: -> { collected } },
                   if: :collected?

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :miles, numericality: { only_integer: true, greater_than: 0 }

  # Вежливость к составному индексу: сказать «эта позиция в перевозке уже
  # занята» раньше, чем откажет база. `scope:` — это и есть «в пределах».
  validates :position, uniqueness: { scope: :consignment_id }

  # Участки, прошедшие по дороге с таким кодом. `joins` подшивает реестр к
  # запросу и не тянет его объекты: они здесь не нужны.
  scope :through_company, ->(code) { joins(:company).where(companies: { code: code }) }
end
