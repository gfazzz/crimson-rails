# Квитанция о приёмке поставки, пришедшая дому по телеграфу.
class Acceptance < ApplicationRecord
  # Новая квитанция меняет поставку: у строки поставки в списке — копия, и
  # копия обязана устареть (s06e07).
  belongs_to :delivery, touch: true
  has_many :disbursements, dependent: :restrict_with_error

  # cable — кабель Владивосток — Нагасаки, overland — сухопутная линия
  # через Сибирь.
  ROUTES = %w[cable overland].freeze

  # Дата приёмки записана так, как на бланке. Бланк кабеля Большого
  # Северного — по новому стилю, как в Европе. Бланк государственного
  # телеграфа — по старому, как в России: в 1892 году на двенадцать дней
  # позади. Один и тот же день — две разные даты.
  JULIAN_ROUTES = %w[overland].freeze

  # День приёмки по новому стилю — один календарь на всю контору.
  def accepted_day
    JULIAN_ROUTES.include?(route) ? Date.new(accepted_on.year, accepted_on.month, accepted_on.day, Date::JULIAN).gregorian : accepted_on
  end

  validates :line_number, :signed_by, :accepted_on, presence: true
  validates :route, inclusion: { in: ROUTES }

  # Принять квитанцию: записать и оставить записку на выплату.
  #
  # Одна и та же телеграмма — тот же путь и тот же номер линии — ложится в
  # книгу один раз: уникальный индекс на (route, line_number). Квитанция
  # на ту же поставку другим путём или под другим номером — ложится: это
  # другой документ, и его видно в книге. Платить по нему решает не книга
  # квитанций, а книга выплат (DisburseJob).
  def self.receive!(delivery:, route:, line_number:, **details)
    acceptance = create_or_find_by!(route: route, line_number: line_number) do |fresh|
      fresh.assign_attributes(delivery: delivery, **details)
    end
    DisburseJob.perform_later(acceptance)
    acceptance
  end
end
