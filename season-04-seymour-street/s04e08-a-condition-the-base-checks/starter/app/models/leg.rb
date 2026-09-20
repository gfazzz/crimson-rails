# Участок пути: часть перевозки, пройденная одной дорогой.
class Leg < ApplicationRecord
  belongs_to :consignment
  belongs_to :company

  # TODO: дать трём числам имена: принял, вёз, сдал.
  #       `enum` даёт отборы (`Leg.collected`), вопросы (`leg.hauled?`) и
  #       переходы (`leg.delivered!`) — и не даёт гарантии: строка с role = 7
  #       приедет мимо модели. Гарантию ставят в схеме.

  # TODO: принявший участок в перевозке один — сказать это и в модели.
  #       Вежливость к частичному индексу: сужать проверку надо так же, как
  #       `where:` сужает индекс (`conditions:` и `if:`).

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :miles, numericality: { only_integer: true, greater_than: 0 }

  # Вежливость к составному индексу: сказать «эта позиция в перевозке уже
  # занята» раньше, чем откажет база. `scope:` — это и есть «в пределах».
  validates :position, uniqueness: { scope: :consignment_id }

  # Участки, прошедшие по дороге с таким кодом. `joins` подшивает реестр к
  # запросу и не тянет его объекты: они здесь не нужны.
  scope :through_company, ->(code) { joins(:company).where(companies: { code: code }) }
end
