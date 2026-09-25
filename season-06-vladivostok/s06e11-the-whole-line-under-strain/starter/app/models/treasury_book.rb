require "net/http"

# Книга выплат казначейства — со стороны конторы.
#
#   GET /payments?month=1892-05  →  200 {"month": "1892-05", "payments": [
#     {"delivery": "NGS-0512", "receipt": "НГС-7712", "kopecks": 240000}, …]}
#
# Адрес — Rails.configuration.x.treasury_book.
module TreasuryBook
  # Казначейство закрыто или молчит — пройдёт.
  class Down < StandardError; end

  module_function

  # TODO: `TreasuryBook.payments(month)` — массив выплат из ответа. Чужая
  #       система: предел ожидания, молчание и 5xx — Down, повторы решает
  #       задача (s06e05).
end
