# Телеграмма, которую контора отдаёт на линию Большого Северного.
class Telegram < ApplicationRecord
  belongs_to :delivery, optional: true

  # pending — лежит в конторе, sent — линия приняла и дала номер,
  # failed — линия отказала, и повторять бесполезно (s06e03).
  enum :state, { pending: "pending", sent: "sent", failed: "failed" }, default: "pending"

  # Наш номер отправления. Даётся при заведении и не меняется: по нему
  # линия узнаёт, что эту телеграмму ей уже подавали (s06e05).
  before_validation { self.key ||= SecureRandom.uuid }

  validates :addressee, :body, presence: true
  validates :key, uniqueness: true
  validates :number, uniqueness: true, allow_nil: true
end
