# frozen_string_literal: true

module Abacus
  # Запись ведомости как объект-значение.
  #
  # Значение — это то, что не имеет судьбы: две записи с одинаковыми полями
  # равны и взаимозаменяемы. Ровно поэтому запись неизменяема.
  class Entry
    FIELDS = %i[road cargo weight charge].freeze

    attr_reader(*FIELDS)

    def initialize(road:, cargo:, weight:, charge:)
      @road = road
      @cargo = cargo
      @weight = weight
      @charge = charge
      freeze
    end

    # Из хеша с любыми ключами: контора шлёт строками, Палата — символами.
    def self.from(row)
      new(**Keys.symbolize(row).slice(*FIELDS))
    end

    def to_h
      { road: road, cargo: cargo, weight: weight, charge: charge }
    end

    # Равенство по значению. Чужой класс — не равен, и это не ошибка.
    def ==(other)
      other.instance_of?(self.class) && to_h == other.to_h
    end

    # eql? обязан согласовываться с hash: по ним работают Hash, Set и uniq.
    alias eql? ==

    # Класс входит в хеш-код: иначе запись могла бы совпасть с чужим объектом
    # тех же полей.
    def hash
      [self.class, to_h].hash
    end

    # Человеку.
    def to_s
      "#{road} #{cargo} #{weight} кг #{charge} сен"
    end

    # Программисту: видно класс и имена полей.
    def inspect
      fields = FIELDS.map { |name| "#{name}=#{public_send(name).inspect}" }.join(" ")
      "#<#{self.class} #{fields}>"
    end
  end
end
