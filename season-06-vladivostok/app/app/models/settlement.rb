# Расчёт с дорогой за месяц.
class Settlement < ApplicationRecord
  # Расчёт, который пытаются оплатить второй раз.
  class AlreadyPaid < StandardError; end

  belongs_to :company

  # Адрес расчёта в пределах дороги — его месяц: «1891-09». Пара «дорога +
  # месяц» уникальна (s04e09), и в листе дороги месяц — ключ.
  def to_param = period

  enum :state, { pending: 0, paid: 1 }

  validates :period, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :period, uniqueness: { scope: :company_id }
  validates :pence, numericality: { only_integer: true, greater_than: 0 }

  # Оплаченный расчёт не переписывают. Не потому, что нельзя поправить
  # ошибку, — а потому, что деньги уже ушли, и новая сумма сделает вид, что
  # ушла другая.
  validate :on_paid_the_sum_is_final, on: :update

  # ─── счёт ───────────────────────────────────────────────────────────────

  # Доли дорог за месяц: плата перевозки делится между участками по милям.
  def self.shares_for(period)
    window = month(period)
    totals = Hash.new(0)

    Consignment.sent_between(window.first, window.last).includes(:legs).find_each do |shipment|
      miles = shipment.legs.sum(&:miles)
      next if miles.zero?

      shipment.legs.each do |leg|
        totals[leg.company_id] += shipment.pence * leg.miles / miles
      end
    end

    totals
  end

  # Посчитать месяц и записать.
  #
  # Всё, что ниже, — одна проводка. Счёт идёт по нескольким строкам сразу:
  # расчёт каждой дороги плюс отметка на перевозках. Лечь это обязано целиком
  # или не лечь вовсе — иначе у Палаты окажется месяц, посчитанный наполовину,
  # и узнает она об этом в день выплаты.
  #
  # Повторный вызов даёт тот же итог, а не второй: строки ищутся по паре
  # «дорога + месяц», и за этой парой стоит уникальный индекс.
  def self.settle!(period)
    window = month(period)

    transaction do
      Consignment.sent_between(window.first, window.last).update_all(settled: true)

      shares_for(period).each do |company_id, pence|
        record = find_or_initialize_by(company_id: company_id, period: period)
        record.pence = pence
        record.save!
      end
    end
  end

  def self.month(period)
    first = Date.strptime(period, "%Y-%m")
    first..first.end_of_month
  end

  # ─── выплата ────────────────────────────────────────────────────────────

  # Оплатить расчёт. Ровно один раз.
  #
  # `with_lock` делает две вещи, и вторая важнее: открывает проводку **и
  # перечитывает строку** с блокировкой. Без перечитывания проверка «уже
  # оплачен?» смотрит в копию, взятую минуту назад, — а за минуту её мог
  # оплатить кто-то другой.
  def pay!
    with_lock do
      raise AlreadyPaid, "расчёт #{period} с #{company.code} уже оплачен" if paid?

      update!(state: :paid)
    end
  end

  private

  def on_paid_the_sum_is_final
    return unless state_was == "paid" && pence_changed?

    errors.add(:base, "расчёт уже оплачен: сумма окончательна")
  end
end
