# Перевозка.
#
# Валидации здесь делают две вещи, которых схема делать не умеет: называют
# поле, которое не понравилось, и объясняют почему. Ни одна из них не защищает
# базу — за каждой обязано стоять ограничение, и в s04e08 они появятся.
class Consignment < ApplicationRecord
  # С Rails 5 `belongs_to` обязателен по умолчанию: объект без дороги
  # негоден. Это валидация — то есть вежливость; гарантию даёт внешний ключ.
  belongs_to :company

  # Участок без своей перевозки не значит ничего: здесь `:destroy` — верное
  # решение, в отличие от s04e05, где перевозки дороги имели цену сами по
  # себе. Признак тот же: есть ли у связанных записей смысл в одиночку.
  has_many :legs, -> { order(:position) }, dependent: :destroy, inverse_of: :consignment

  # Дороги, по которым прошла перевозка, — через участки. `through` читает
  # связь по цепочке, а не заводит вторую.
  has_many :companies, through: :legs
  normalizes :reference, with: ->(reference) { reference.strip.upcase }

  # Не гарантия, а вежливость: гарантию даёт уникальный индекс.
  validates :reference, presence: true, uniqueness: true
  validates :description, presence: true
  validates :sent_on, presence: true

  # `numericality` без `allow_nil` отвергает и пустое значение: «не число».
  # Отдельная `presence` здесь была бы второй жалобой об одном и том же.
  validates :pence, numericality: { only_integer: true, greater_than: 0 }
  validates :weight_lb, numericality: { only_integer: true, greater_than: 0 }
end
