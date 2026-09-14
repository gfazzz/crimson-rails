# frozen_string_literal: true

# Abacus — счётная библиотека Расчётной палаты.
#
# Единственная точка входа: require "abacus" подтягивает всё остальное.
# Внутренние файлы напрямую не требуют — это и есть смысл единицы поставки.
module Abacus
  VERSION = "1.0.0"
end

# Порядок важен там, где один файл нужен другому в момент чтения:
# dynamic.rb делает include Totals, значит Totals должен быть уже определён.
require "abacus/errors"
require "abacus/keys"
require "abacus/convertible"
require "abacus/entry"
require "abacus/ledger"
require "abacus/reports"
require "abacus/tariff"
require "abacus/registry"
require "abacus/macros"
require "abacus/totals"
require "abacus/dynamic"
