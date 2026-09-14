# frozen_string_literal: true

module Abacus
  # Правила тарифа одной дороги.
  #
  # Тариф неизменяем: изменённая копия создаётся методом with, а сам объект
  # остаётся прежним. Правило, которое меняется под ногами, нельзя проверить.
  class Tariff
    KNOWN = %i[base_rate minimum rounding].freeze
    ROUNDINGS = %i[up down nearest].freeze

    attr_reader :base_rate, :minimum, :rounding

    # base_rate обязателен и не имеет умолчания: тариф без ставки — не тариф.
    # Остальное имеет разумные умолчания.
    def initialize(base_rate:, minimum: 0, rounding: :up)
      unless ROUNDINGS.include?(rounding)
        raise ArgumentError, "округление #{rounding.inspect} неизвестно; есть: #{ROUNDINGS.inspect}"
      end

      @base_rate = base_rate
      @minimum = minimum
      @rounding = rounding
      freeze
    end

    # Сборка из присланных правил. Лишние ключи — ошибка, а не мусор:
    # опечатка в имени правила должна быть слышна сразу.
    def self.from(**options)
      unknown = options.keys - KNOWN
      unless unknown.empty?
        raise ArgumentError,
              "неизвестные правила тарифа: #{unknown.inspect}; известны: #{KNOWN.inspect}"
      end

      new(**options)
    end

    # Изменённая копия. Сам тариф не меняется.
    def with(**overrides)
      self.class.from(**to_h, **overrides)
    end

    def to_h
      { base_rate: base_rate, minimum: minimum, rounding: rounding }
    end

    # Плата за перевозку.
    #
    # surcharge — надбавка в сенах, discount — доля скидки (0.15 = 15 %).
    # Оба именованные: на месте вызова видно, что именно означает число.
    def charge_for(entry, surcharge: 0, discount: 0)
      raise ArgumentError, "скидка #{discount} вне [0, 1]" unless (0..1).cover?(discount)

      raw = base_rate * entry.fetch(:weight) / 100.0
      raw += surcharge
      raw -= raw * discount
      raw = minimum if raw < minimum
      round(raw)
    end

    private

    def round(value)
      case rounding
      when :up      then value.ceil
      when :down    then value.floor
      when :nearest then value.round
      end
    end
  end
end
