# frozen_string_literal: true

# s01e14 — Единица поставки
#
# В этой серии артефакта два — так устроена упаковка:
#
#   cp starter.rb          artifacts/abacus.rb
#   cp starter.gemspec     artifacts/abacus.gemspec
#   make test
#
# Модули прошлых серий лежат готовыми в support/lib/abacus/.

# TODO: объявить модуль Abacus и константу VERSION вида "1.0.0",
#       замороженную и неизменяемую.

# TODO: подтянуть все файлы библиотеки через require (не require_relative:
#       гем находит свои файлы через $LOAD_PATH, а не через путь к файлу).
#
# Файлы: errors, keys, convertible, entry, ledger, reports, tariff,
#        registry, macros, totals, dynamic.
#
# TODO: порядок не произволен. Один из файлов подключает модуль из другого
#       в момент чтения класса — если тот ещё не определён, будет NameError.
#       Найди эту пару.
