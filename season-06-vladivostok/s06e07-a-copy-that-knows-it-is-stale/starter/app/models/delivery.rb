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

  # ─── сводка за месяц ────────────────────────────────────────────────────

  # Сводка поставок за месяц («1892-05»): сколько пароходов пришло к причалу
  # и со сколькими шпалами, сколько квитанций пришло каким путём и сколько
  # казна выплатила. Считается по трём книгам — и считается долго.
  def self.summary(month)
    window = Time.zone.parse("#{month}-01").all_month
    arrived = where(arrived_on: window.first.to_date..window.last.to_date)

    {
      month: month,
      steamers: arrived.count,
      sleepers: arrived.sum(:sleepers),
      receipts: Acceptance.where(accepted_on: window.first.to_date..window.last.to_date).group(:route).count,
      paid_kopecks: Disbursement.where(paid_at: window).sum(:kopecks)
    }
  end

  # Та же сводка — из копии, если копия не устарела.
  #
  # TODO: копия в Rails.cache. Ключ обязан измениться, когда в любой из трёх
  #       книг, из которых сводка сосчитана, строку добавили, поправили или
  #       убрали.
  def self.cached_summary(month)
    summary(month)
  end
end
