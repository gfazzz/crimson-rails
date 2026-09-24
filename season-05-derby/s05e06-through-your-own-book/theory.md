# Теория — s05e06

## 1. Вложенный маршрут

```ruby
resources :companies, param: :code do
  resources :consignments, only: %i[index show], param: :reference
end
```

Внутренний ресурс получает префикс адреса и имени:

| Имя | Адрес | Параметры |
|---|---|---|
| `company_consignments` | `/companies/:company_code/consignments` | `company_code` |
| `company_consignment` | `/companies/:company_code/consignments/:reference` | `company_code`, `reference` |

Имя параметра родителя — имя ресурса в единственном числе и его `param:`:
`company` + `code`. Ограничения родителя Rails переносит на вложенный
параметр сам.

Помощник принимает записи по порядку вложенности:
`company_consignment_path(company, consignment)`; или массивом —
`polymorphic_path([company, consignment])`, и тогда то же самое умеют
`link_to` и `form_with model: [company, consignment]`.

## 2. Поиск в пределах родителя

```ruby
@company.consignments.find_by!(reference: params[:reference])
```

```sql
SELECT consignments.* FROM consignments
WHERE consignments.company_id = ? AND consignments.reference = ? LIMIT 1
```

Связь `has_many` — это не массив, а отношение с условием: всё, что на нём
зовут, получает `WHERE company_id = ?`. Поиск, заведение (`build`, `create`),
подсчёт — все остаются в пределах дороги.

Это главный приём защиты от доступа к чужой записи по подставленному адресу
(в OWASP — Insecure Direct Object Reference): **запись ищут через то, что
запросившему принадлежит**, а не во всей таблице.

## 3. Насколько глубоко вкладывать

Правило из Rails Guides: **не глубже одного уровня.**

```ruby
resources :companies do
  resources :consignments do
    resources :legs          # /companies/MID/consignments/B-0992/legs/2 — уже много
  end
end
```

Адрес в три уровня трудно читать и почти всегда избыточен: у участка есть
свой ключ. Выход — неглубокая вложенность:

```ruby
resources :companies do
  resources :consignments, shallow: true
end
```

| Действие | Адрес |
|---|---|
| `index`, `new`, `create` | `/companies/MID/consignments` — нужен родитель |
| `show`, `edit`, `update`, `destroy` | `/consignments/B-0992` — хватает своего ключа |

Окну неглубокая вложенность не подходит, и это решение, а не упущение: вопрос
кассы — «есть ли бланк в книге этой дороги», и родитель в адресе нужен
именно на `show`.

## 4. 404, 403 и перенаправление

| Ответ на чужую запись | Что раскрывает |
|---|---|
| 200 | всё |
| 302 к хозяину | что запись есть и чья она |
| 403 Forbidden | что запись есть |
| 404 Not Found | ничего |

404 — стандартный ответ, когда само существование записи — не дело
спросившего. GitHub отвечает 404 на закрытый репозиторий, а не 403, ровно по
этой причине.

## 5. `includes` в шаблоне

```ruby
@legs = @consignment.legs.includes(:company)
```

| Без `includes` | С `includes` |
|---|---|
| 1 запрос за участками + N за дорогами | 1 за участками + 1 за всеми их дорогами |

Проверка «страница спрашивает одинаково при двух и при шести» — способ
увидеть N+1, не читая журнал. Его же используют в тестах больших приложений:
число запросов не должно зависеть от числа строк.

Порядок участков задан у самой связи (`-> { order(:position) }`, s04e06), и
`includes` его сохраняет.

## 6. Второй естественный ключ

`Consignment#to_param = reference` — то же, что `Company#to_param = code`
(s05e02). Два требования те же: уникален (индекс с s04e04) и почти неизменен
(номер бланка выписан на бумаге).

Номер бланка содержит дефис, и адрес с ним в порядке. Точка — нет: Rails
читает `/B.0992` как бланк `B` в формате `0992`. Если в ключе бывают точки,
маршруту дают `constraints: { reference: /[^\/]+/ }`.

## 7. Чего эта серия не закрывает

- **заведение перевозки через книгу** (`form_with model: [company, consignment]`)
  — бланк по-прежнему вносится формой s05e04;
- **права: кто вправе открыть чужую книгу** — сезон 7;
- **постраничный вывод длинной книги** — сезон 6 вместе с кешем.

## 8. Куда смотреть дальше

- **Rails Guides: Rails Routing from the Outside In** — «Nested Resources»,
  «Limits to Nesting», «Shallow Nesting».
- **Rails Guides: Active Record Associations** — методы `has_many`.
- **OWASP: Insecure Direct Object Reference Prevention Cheat Sheet**.

## Спросить у ADA

- «Какой SQL даёт `@company.consignments.find_by!` и какой — `Consignment.find_by!`?»
- «Когда неглубокая вложенность лучше полной?»
- «Почему на чужую запись честнее 404, чем 403?»
- «Как увидеть N+1, не читая журнал запросов?»
