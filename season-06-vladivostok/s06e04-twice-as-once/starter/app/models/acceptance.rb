# Квитанция о приёмке поставки, пришедшая дому по телеграфу.
class Acceptance < ApplicationRecord
  belongs_to :delivery
  has_many :disbursements, dependent: :restrict_with_error

  # cable — кабель Владивосток — Нагасаки, overland — сухопутная линия
  # через Сибирь.
  ROUTES = %w[cable overland].freeze

  validates :line_number, :signed_by, :accepted_on, presence: true
  validates :route, inclusion: { in: ROUTES }
  validates :line_number, uniqueness: { scope: :route }

  # Принять квитанцию: записать и оставить записку на выплату (DisburseJob).
  #
  # Одна и та же телеграмма (тот же путь и номер линии), пришедшая дважды, —
  # одна строка в книге. Квитанция на ту же поставку другим путём — своя
  # строка: это другой документ.
  def self.receive!(delivery:, route:, line_number:, **details)
    # TODO
  end
end
