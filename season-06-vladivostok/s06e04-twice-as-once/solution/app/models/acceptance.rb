# Квитанция о приёмке поставки, пришедшая дому по телеграфу.
class Acceptance < ApplicationRecord
  belongs_to :delivery
  has_many :disbursements, dependent: :restrict_with_error

  # cable — кабель Владивосток — Нагасаки, overland — сухопутная линия
  # через Сибирь.
  ROUTES = %w[cable overland].freeze

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
