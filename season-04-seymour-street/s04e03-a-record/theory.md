# Теория — s04e03

## 1. Что такое Active Record

Шаблон, описанный Фаулером: объект, который несёт и данные строки, и
поведение, связанное с ней. Класс соответствует таблице, экземпляр — строке,
атрибуты — столбцам.

Rails выводит связь из имени по соглашению: `Company` → `companies`,
`Consignment` → `consignments`, `PersonAddress` → `person_addresses`. Спорить
с соглашением можно (`self.table_name = "..."`), но каждый такой спор потом
приходится помнить.

Атрибуты создаются **из схемы**, а не из кода модели. Поэтому в модели нет
списка полей: Rails читает его у базы при загрузке класса. Отсюда и то, что
`Consignment.new.settled` возвращает `false` — умолчание прочитано из схемы, и
дублировать его в модели значит завести второе место, где оно записано.

## 2. Жизнь записи

```ruby
c = Company.new(name: "Мидлендская дорога", code: "MID")
c.new_record?   # true
c.save          # INSERT
c.persisted?    # true
c.id            # номер назначила база

c.name = "..."
c.save          # UPDATE только изменённых столбцов
c.destroy       # DELETE
```

`create` = `new` + `save`. `find`, `find_by`, `where` — следующая серия про
запросы (`s04e07`).

Отдельно: `save` возвращает `false`, если валидации не прошли. Запроса при
этом не было — база ничего не знает о попытке.

## 3. Пара с восклицательным знаком

| Без `!` | С `!` | Когда |
|---|---|---|
| `save` | `save!` | есть кому показать ошибку / некому |
| `update` | `update!` | то же |
| `create` | `create!` | то же |
| `find_by` (даёт `nil`) | `find_by!` (бросает) | ожидаемое отсутствие / неожиданное |

Признак простой: **`!` — там, где тихий отказ никто не прочтёт.** В контроллере
с формой нужен `save`, потому что ошибку покажут; в задаче очереди и в скрипте
переноса нужен `save!`, потому что `false` уйдёт в пустоту.

`find` бросает `RecordNotFound` без всякого `!` — историческое исключение,
которое приходится помнить.

## 4. Валидации

```ruby
validates :name, presence: true
validates :code, presence: true, length: { in: 2..4 }
validates :pence, numericality: { only_integer: true, greater_than: 0 }
validates :email, format: { with: /.../ }
validates :state, inclusion: { in: %w[held sent failed] }
```

Работают на `valid?`, `save`, `update`, `create`. **Не работают** на
`insert_all`, `update_all`, `delete_all`, `update_attribute`, `update_column`,
`touch`, а также на всём, что приходит в базу не через Rails.

Результат — `errors`: объект, где ошибки привязаны к полям.
`errors[:name]`, `errors.full_messages`, `errors.added?(:name, :blank)`.

Про `allow_nil` и `allow_blank` стоит помнить одно: они выключают правило для
пустого значения. Рядом со столбцом `null: false` это означает «пропустить в
базу то, что база отвергнет», то есть падение вместо сообщения.

**Своя валидация** пишется методом:

```ruby
validate :sent_on_is_not_in_the_future

def sent_on_is_not_in_the_future
  errors.add(:sent_on, "позже сегодняшнего дня") if sent_on && sent_on > Date.current
end
```

## 5. Приведение: `normalizes`

```ruby
normalizes :code, with: ->(code) { code.strip.upcase }
```

Rails 7.1+. Применяется при присваивании, перед валидацией и записью — и, что
важнее, **в запросах**: `Company.find_by(code: " mid ")` найдёт `MID`.

Чем отличается от `before_save`: `before_save` срабатывает после валидации и
не влияет на поиск. Значит, проверяется одно значение, а сохраняется другое, и
`find_by` промахивается.

Чем отличается от `before_validation`: почти ничем, кроме поиска — и этого
«почти» хватает, чтобы предпочесть `normalizes`.

## 6. Что изменилось: `ActiveModel::Dirty`

```ruby
c.changed?                 # есть ли несохранённые изменения
c.changed                  # ["name"]
c.changes                  # {"name" => ["было", "стало"]}
c.name_was                 # прежнее значение
c.name_changed?
c.save!
c.saved_change_to_name?    # уже после сохранения
c.name_previously_was
```

Пара «до сохранения / после сохранения» появилась в Rails 5.2 и до сих пор
путает: внутри `before_save` смотрят `changed?`, внутри `after_save` —
`saved_change_to_*`.

На этом же держится частичное обновление: Rails шлёт `UPDATE` только по
изменённым столбцам.

## 7. Колбэки — коротко и с предупреждением

`before_validation`, `after_validation`, `before_save`, `after_save`,
`before_create`, `after_create`, `after_commit`, `after_rollback` и другие.

Полезны для того, что относится к самой записи: привести значение, посчитать
производное поле. Опасны для всего остального — писем, задач очереди, походов
в чужие системы: такой колбэк срабатывает и в тестах, и в скриптах переноса, и
в `seeds.rb`, и отменить его нельзя.

Правило, которое стоит унести: **колбэк, который делает что-то за пределами
записи, — это скрытый вызов.** Его не видно в месте, где он произошёл.

## 8. Чего эта серия не закрывает

- **уникальность** — `s04e04`, и там же выяснится, чего не умеет
  `validates :uniqueness`;
- **связи** — `s04e05`;
- **запросы** — `s04e07`;
- **ограничения в схеме за валидациями** — `s04e08`;
- **объекты-значения и сервисные объекты** — сезон 5.

## 9. Куда смотреть дальше

- **Rails Guides: Active Record Basics**, **Validations**, **Callbacks**.
- **API: `ActiveModel::Dirty`**, **`ActiveRecord::Normalization`**.
- **Fowler M. — Patterns of Enterprise Application Architecture**, глава
  Active Record (и Data Mapper рядом — чтобы видеть, чем Rails не является).

## Спросить у ADA

- «Дай признак, по которому выбирают между `save` и `save!`.»
- «Чем `normalizes` отличается от `before_validation` и от `before_save`?»
- «Какие методы Active Record обходят валидации? Перечисли все.»
- «Когда `changed?`, а когда `saved_change_to_*`?»
