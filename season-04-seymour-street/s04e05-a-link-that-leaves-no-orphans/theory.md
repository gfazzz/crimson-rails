# Теория — s04e05

## 1. Связь живёт в двух местах

| Место | Что даёт | Кого касается |
|---|---|---|
| `belongs_to` / `has_many` в модели | способ найти одно по другому; валидация присутствия | пришедших через модель |
| внешний ключ в схеме | ссылка ведёт на существующую строку | всех |

Путать их — обычная и дорогая ошибка: связь в модели выглядит как готовая
работа, потому что после неё всё «работает».

## 2. `add_reference`

```ruby
add_reference :consignments, :company, null: false, foreign_key: true
```

Разворачивается в три действия:

```ruby
add_column :consignments, :company_id, :bigint, null: false
add_index  :consignments, :company_id
add_foreign_key :consignments, :companies
```

Полезные аргументы: `index: { unique: true }` (связь «один к одному»),
`polymorphic: true` (добавляет ещё и `_type`, но внешнего ключа тогда не
будет — у полиморфной связи его нельзя поставить), `type: :uuid`,
`foreign_key: { to_table: :companies, on_delete: :cascade }`.

**`null: false` и внешний ключ — разные правила.** Первое требует, чтобы ссылка
была; второе — чтобы она вела на существующее. `NULL` внешний ключ пропускает
всегда: «ссылки нет» не считается нарушением.

## 3. Почему индекс рядом с ключом

Два повода, и второй важнее.

**Чтение.** `company.consignments` без индекса читает всю ведомость.

**Удаление.** Когда удаляют строку из `companies`, база обязана убедиться, что
на неё никто не ссылается, — то есть просмотреть `consignments` по
`company_id`. Без индекса каждое удаление дороги превращается в полный
просмотр ведомости; на большой таблице это блокировки и минуты.

PostgreSQL индекс под внешний ключ **не создаёт автоматически** — в отличие от
MySQL. Rails создаёт его через `add_reference`, и это одна из причин
пользоваться им, а не `add_column`.

## 4. `belongs_to` и `has_many`

```ruby
belongs_to :company                  # столбец company_id здесь
has_many :consignments               # столбца здесь нет
```

Правило: **кто ссылается, тот и принадлежит.** Столбец с ключом лежит на
стороне `belongs_to`.

Нестандартные имена:

```ruby
belongs_to :sender, class_name: "Company", foreign_key: :sender_id
has_many :sent_consignments, class_name: "Consignment", foreign_key: :sender_id,
         inverse_of: :sender
```

`inverse_of` Rails обычно выводит сам; при нестандартных именах его указывают
руками, иначе `consignment.sender.sent_consignments.first` окажется другим
объектом в памяти, и изменения разойдутся.

С Rails 5 `belongs_to` обязателен по умолчанию
(`config.active_record.belongs_to_required_by_default`). `optional: true`
снимает валидацию — и только её.

## 5. `dependent:` целиком

| Значение | Что делает | Колбэки | Запросов |
|---|---|---|---|
| `:destroy` | удаляет связанные по одной | да | N + 1 |
| `:destroy_async` | то же, но в фоне | да | ставит задачу |
| `:delete_all` | удаляет одним `DELETE` | нет | 1 |
| `:nullify` | обнуляет ссылку | нет | 1 |
| `:restrict_with_error` | отказывает, ошибка в `errors` | — | 1 (проверка) |
| `:restrict_with_exception` | отказывает падением | — | 1 |

Признак выбора: **есть ли у связанных записей ценность сами по себе.** Строки
заказа без заказа не имеют смысла — `:destroy`. Перевозки без дороги имеют
(это деньги) — `:restrict_*`.

`dependent:` не действует на `delete`, `delete_all`, `update_column` и на
всё, что идёт мимо модели. Там отказывает только внешний ключ.

## 6. `on_delete` на стороне базы

```ruby
add_foreign_key :consignments, :companies, on_delete: :cascade
add_foreign_key :consignments, :companies, on_delete: :nullify
add_foreign_key :consignments, :companies, on_delete: :restrict   # по умолчанию
```

База умеет то же, что `dependent:`, но быстрее и для всех. Цена — колбэки
моделей не сработают, и приложение не узнает, что строки исчезли.

Разумное сочетание: `dependent: :restrict_with_error` в модели (объясняет) и
`on_delete: :restrict` в схеме (гарантирует). Каскад в базе ставят там, где
связанные записи действительно служебные.

## 7. Сироты

Строка, ссылающаяся на несуществующую. Особенность — она не болит сразу:
`JOIN` её просто не найдёт, свод сойдётся не полностью, и однажды сумма
разойдётся на величину, которую никто не объяснит.

```sql
SELECT c.* FROM consignments c
LEFT JOIN companies co ON co.id = c.company_id
WHERE co.id IS NULL;
```

Этот запрос — то, чего стоит внешний ключ: чтобы он никогда не понадобился.

Отдельно: **SQLite проверяет внешние ключи только при включённом
`PRAGMA foreign_keys`**. Rails включает его сам, но если вы работаете с базой
консолью `sqlite3`, ключи там по умолчанию выключены.

## 8. Чего эта серия не закрывает

- **связь «многие ко многим»** и промежуточная модель со своими полями —
  `s04e06`;
- **N+1 при обходе связей** — `s04e07`;
- **полиморфные связи** — в курсе не понадобятся; стоит знать, что внешнего
  ключа у них не бывает, и это их главная цена;
- **`through` в глубину, `counter_cache`, `touch`** — сезон 5.

## 9. Куда смотреть дальше

- **Rails Guides: Active Record Associations** — целиком.
- **Rails Guides: Active Record Migrations**, раздел про внешние ключи.
- **SQLite: Foreign Key Support** — про `PRAGMA foreign_keys`.
- **PostgreSQL: Constraints**, раздел Foreign Keys.

## Спросить у ADA

- «Чем `null: false` на `company_id` отличается от внешнего ключа?»
- «Почему PostgreSQL не создаёт индекс под внешний ключ сам и чем это
  грозит?»
- «Дай признак выбора между `dependent: :destroy` и `:restrict_with_error`.»
- «Что делает `inverse_of` и когда его отсутствие заметно?»
