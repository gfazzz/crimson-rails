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

  # ─── отборы ─────────────────────────────────────────────────────────────
  #
  # Отбор — это не запрос, а его кусок. Он ничего не спрашивает у базы, пока
  # у него самого не спросят; поэтому куски складываются, и запрос уходит один.

  scope :unsettled, -> { where(settled: false) }
  scope :sent_between, ->(from, to) { where(sent_on: from..to) }
  scope :through_company, ->(code) { where(id: Leg.through_company(code).select(:consignment_id)) }

  # ─── своды ──────────────────────────────────────────────────────────────

  # Маршрутный лист: по какой перевозке какие дороги шли.
  #
  # Без `includes` это классический N+1: один запрос за перевозками, потом по
  # запросу за участками каждой и ещё по запросу за дорогой каждого участка.
  # На двадцати перевозках по три участка — восемьдесят один запрос вместо
  # трёх, и растёт это с числом строк, а не с числом связей.
  def self.route_sheet(relation = all)
    relation.includes(legs: :company).map do |record|
      { reference: record.reference, roads: record.legs.map { |leg| leg.company.code } }
    end
  end

  # Сколько миль прошла каждая дорога по отобранным перевозкам.
  #
  # Считает база, а не Ruby: свод по восьми тысячам перевозок, собранный
  # объектами, — это восемь тысяч объектов, которые потом выбросят.
  def self.miles_by_company(relation = all)
    Leg.where(consignment_id: relation.select(:id)).group(:company_id).sum(:miles)
  end
end
