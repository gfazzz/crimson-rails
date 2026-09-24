# Реестр дорог для телеграфного аппарата: код, название и адрес листа.
#
# Адрес — полный, со схемой и хостом: аппарат не знает, откуда пришёл ответ.
json.array! @companies do |company|
  json.code company.code
  json.name company.name
  json.url company_url(company, format: :json)
  json.settlements_url company_settlements_url(company, format: :json)
end
