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

  # ─── табло причала ──────────────────────────────────────────────────────

  # Что написано о поставке на табло: одно слово, по самому дальнему шагу.
  def board_state
    if disbursements.any? then "оплачено"
    elsif acceptances.any? then "квитанция"
    elsif arrived? then "у причала"
    else "в море"
    end
  end

  # Поток табло причала.
  PIER = "pier"

  # TODO: табло обновляется само. Новая поставка — её строка добавляется в
  #       конец табло (цель — tbody с id «pier»); изменилась поставка —
  #       её строка заменяется. Строку (board/_delivery) рисует работник, и
  #       только после того, как правка легла.

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
  # Копия знает, что устарела, по ключу: в ключе — версии всех трёх книг,
  # из которых она сосчитана. Версия книги (`cache_key_with_version` у
  # выборки) — число строк и время последней правки: добавили строку,
  # поправили, убрали — версия другая, и старая копия больше не найдётся.
  # Время последней правки в одиночку не годится: убранная строка его не
  # меняет.
  def self.cached_summary(month)
    window = Time.zone.parse("#{month}-01").all_month
    days = window.first.to_date..window.last.to_date
    books = [where(arrived_on: days), Acceptance.where(accepted_on: days), Disbursement.where(paid_at: window)]

    Rails.cache.fetch(["summary", month, *books.map(&:cache_key_with_version)]) { summary(month) }
  end
end
