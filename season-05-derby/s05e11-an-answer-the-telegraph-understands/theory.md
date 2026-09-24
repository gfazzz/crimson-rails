# Теория — s05e11

## 1. Как Rails узнаёт формат

Для каждого запроса Rails вычисляет `request.format` — что спрашивающий
готов принять:

| Источник | Пример | Когда главный |
|---|---|---|
| расширение в адресе | `/settlements.json` | всегда, если есть |
| параметр `format` | `?format=json` | если расширения нет |
| заголовок `Accept` | `Accept: application/json` | если нет ни того, ни другого |

С одной оговоркой: браузеры шлют `Accept` вида `text/html,…,*/*;q=0.8`, и
Rails, увидев `*/*` среди прочего, такой заголовок игнорирует и считает запрос
HTML-ным. Программы вроде `curl` или аппарата шлют `Accept` точно, и его
уважают.

## 2. `respond_to`

```ruby
respond_to do |format|
  format.html
  format.json
  format.csv { send_data … }
end
```

| Случай | Что будет |
|---|---|
| формат есть в блоке, без блока | шаблон `действие.формат.*` |
| формат есть, с блоком | блок |
| формата нет | `ActionController::UnknownFormat` — 406 |
| действие без `respond_to` и без шаблона под формат | `MissingExactTemplate` — 406 |

`format.any` отвечает на всё — и отнимает единственный способ сказать «ты
спросил не то». Годится редко.

Свой формат регистрируют в `config/initializers/mime_types.rb`
(`Mime::Type.register`); `csv` в Rails уже есть.

## 3. Jbuilder

```ruby
json.company @company.code
json.settlements @settlements do |settlement|
  json.period settlement.period
  json.pence settlement.pence
end
```

Шаблон `index.json.jbuilder` — тот же шаблон, что `.html.erb`: в нём видны
переменные контроллера и помощники (`money`, `company_url`). Альтернатива —
`render json: объект.as_json(only: …)`; Jbuilder выигрывает, когда форма
ответа не совпадает с формой таблицы, а у договора она почти никогда не
совпадает.

Три правила формы JSON:

| Правило | Почему |
|---|---|
| деньги — целыми наименьшими единицами | дробь теряет, строку придётся разбирать |
| имена полей постоянны | на них рассчитывает тот, кто читает |
| адреса — полные (`*_url`) | ответ читают вне страницы, без базового адреса |

## 4. Файл

```ruby
send_data csv, type: :csv, disposition: "attachment", filename: "MID-settlements.csv"
```

| `Content-Disposition` | Что сделает браузер |
|---|---|
| `inline` | покажет в окне, если умеет |
| `attachment; filename="…"` | предложит сохранить под этим именем |

`send_file` — то же для файла с диска. Для больших файлов — потоковая отдача
(`response.stream`); сезону не нужна.

Ссылка на файл на странице: `download` или `data-turbo="false"`. Turbo
перехватывает ссылки, чтобы рисовать страницы, и файл для него — страница,
которую нарисовать не выйдет.

## 5. Ошибки в формате вопроса

В производственной среде `ActionDispatch::PublicExceptions` сам отвечает на
404 для JSON-запроса JSON-ом. Но полагаться на среду — значит получить разное
поведение в разработке, тестах и на проде. Явное решение одно на всё окно:

```ruby
rescue_from ActiveRecord::RecordNotFound do |error|
  raise error unless request.format.json?
  render json: { error: "not_found", message: "…" }, status: :not_found
end
```

`raise` внутри `rescue_from` отдаёт исключение дальше — обычной обработке, и
человек получает свою страницу 404.

## 6. Приёмка обходом

Приёмочная проверка сезона не перечисляет адресов — она читает таблицу
маршрутов:

```ruby
Rails.application.routes.routes.select { |item| item.verb == "GET" }
# item.required_parts  → [:company_code, :reference]
# item.format(values)  → "/companies/MID/consignments/B-0992"
```

Так проверка растёт вместе с окном: новый маршрут попадает в обход сам. То же
делают большие приложения: «у каждого маршрута есть действие», «каждая
страница отвечает без 500», «каждая форма уходит туда, где её принимают» —
проверки, которые не устаревают.

## 7. Чего эта серия не закрывает

- **версии формы ответа** (`/v1/…`, заголовок версии) — когда у договора
  больше одного читателя с разной скоростью обновления; сезон 6, интеграции;
- **API без сессии и CSRF** — `ActionController::API`, токены; сезон 7;
- **кеширование ответа по формату** (`ETag`, `fresh_when`) — сезон 6.

## 8. Куда смотреть дальше

- **Rails Guides: Action Controller Overview** — «Rendering», `respond_to`,
  «Sending Files».
- **jbuilder README**.
- **RFC 9110** — 12.5.1 `Accept`, 15.5.7 `406 Not Acceptable`.
- **RFC 6266** — `Content-Disposition`.

## Спросить у ADA

- «В каком порядке Rails смотрит на расширение, параметр и `Accept`?»
- «Почему браузерный `Accept` Rails игнорирует?»
- «Чем Jbuilder лучше `render json: record`?»
- «Как проверить, что у каждой страницы окна есть кому ответить, не
  перечисляя страниц?»
