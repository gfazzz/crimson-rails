# Лист расчётов для телеграфного аппарата.
#
# Форма ответа — договор, как таблица маршрутов: имена полей не меняют, и
# деньги идут целыми пенсами. Чтение фунтами — строкой рядом, не вместо.
json.company @company.code
json.settlements @settlements do |settlement|
  json.period settlement.period
  json.pence settlement.pence
  json.reading money(settlement.pence)
  json.state settlement.state
end
