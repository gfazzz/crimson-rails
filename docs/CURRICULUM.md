# Указатель серий

Генерируется из шапок самих серий: `make docs`. Руками не правят.

## Season 1 — Йокогама · Ruby

серий: 15 · время: 14 ч 05 мин · проверок: 265 · утверждений: 516

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s01e01](../season-01-yokohama/s01e01-one-pass/) — Один обход | блок как аргумент; `yield` и `block_given?` | `ledger.rb` | ~55 мин | ⭐ |
| [s01e02](../season-01-yokohama/s01e02-rule-in-an-envelope/) — Действие в конверте | блок как объект: `&`, `Proc` против `lambda`, замыкание | `ledger.rb` | ~50 мин | ⭐⭐ |
| [s01e03](../season-01-yokohama/s01e03-forty-methods/) — Сорок методов даром | `Enumerable` — контракт «дай `each`, получи остальное» | `ledger.rb` | ~60 мин | ⭐⭐ |
| [s01e04](../season-01-yokohama/s01e04-three-passes/) — Три обхода | `map`, `select`, `reduce` — и когда какой из трёх | `reports.rb` | ~55 мин | ⭐⭐ |
| [s01e05](../season-01-yokohama/s01e05-summary-by-road/) — Свод по дорогам | `group_by`, `tally`, `each_with_object` — свёртка в хеш | `reports.rb` | ~55 мин | ⭐⭐ |
| [s01e06](../season-01-yokohama/s01e06-hash-as-contract/) — Хеш как договор | именованные аргументы, `**`, опции как договор, а не как мешок | `tariff.rb` | ~50 мин | ⭐⭐ |
| [s01e07](../season-01-yokohama/s01e07-symbol-and-string/) — Символ и строка | символ против строки; почему ключи разного вида — разные ключи | `keys.rb` | ~45 мин | ⭐⭐ |
| [s01e08](../season-01-yokohama/s01e08-an-entry-of-its-own/) — Своя запись | объект-значение: `==`, `eql?`, `hash`, `to_s` против `inspect` | `entry.rb` | ~60 мин | ⭐⭐⭐ |
| [s01e09](../season-01-yokohama/s01e09-a-mixin/) — Примесь | модуль как роль: `include`, `extend`, `prepend`, цепочка предков | `convertible.rb` | ~60 мин | ⭐⭐⭐ |
| [s01e10](../season-01-yokohama/s01e10-four-selves/) — Четыре `self` | `self` в методе, в теле класса, в `class << self`, в блоке | `registry.rb` | ~55 мин | ⭐⭐⭐ |
| [s01e11](../season-01-yokohama/s01e11-when-the-ledger-lies/) — Когда ведомость врёт | своя иерархия ошибок, `raise`, `rescue`, `ensure`, `retry` | `errors.rb` | ~55 мин | ⭐⭐⭐ |
| [s01e12](../season-01-yokohama/s01e12-a-question-that-isnt-there/) — Вопрос, которого нет | `method_missing` и `respond_to_missing?` — как работает `find_by_*` | `dynamic.rb` | ~65 мин | ⭐⭐⭐ |
| [s01e13](../season-01-yokohama/s01e13-a-method-nobody-wrote/) — Метод, которого не писали | `define_method`, `send`, объявление полей одной строкой | `macros.rb` | ~60 мин | ⭐⭐⭐ |
| [s01e14](../season-01-yokohama/s01e14-a-unit-of-delivery/) — Единица поставки | гем: точка входа, `require` против `require_relative`, `$LOAD_PATH` | `abacus.rb` + `abacus.gemspec` | ~50 мин | ⭐⭐ |
| [s01e15](../season-01-yokohama/s01e15-someone-elses-code/) — Чужой код | чтение чужого метапрограммирования; приёмка сезона | `concern.rb` | ~70 мин | ⭐⭐⭐⭐ |

---

## Season 2 — Лондон, Сент-Панкрас · HTML и CSS

Не написан. План — в [CONCEPT.md](../CONCEPT.md), маршрут — в [ROUTE.md](ROUTE.md).

## Season 3 — Нью-Йорк · JavaScript

Не написан.

## Season 4–8 — Rails 8

Не написаны. Артефакты: `ledger`, `signal_box`, `dispatch`, `keyring`, `crimson`.
