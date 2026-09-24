# Поставка: пароход со шпалами для постройки Южно-Уссурийской линии.
class Delivery < ApplicationRecord
  has_many :acceptances, dependent: :restrict_with_error
  has_many :disbursements, dependent: :restrict_with_error
  has_many :telegrams, dependent: :nullify

  # Адрес поставки — её номер отгрузки: «NGS-0512» (Нагасаки, отгрузка 512).
  REFERENCE = /[A-Z]{3}-\d{4}/
  def to_param = reference

  validates :reference, format: { with: /\A#{REFERENCE}\z/ }, uniqueness: true
  validates :steamer, presence: true
  validates :sleepers, :kopecks, numericality: { only_integer: true, greater_than: 0 }

  # Пароход у причала. Пока его нет, принимать нечего.
  def arrived? = arrived_on.present?
end
