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

серий: 12 · время: 12 ч 15 мин · проверок: 195 (не измерены без браузера: s02e07, s02e08)

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s02e01](../season-02-st-pancras/s02e01-markup-is-a-claim/) — Разметка — это утверждение | разметка описывает содержание, а не вид | `bradshaw.html` | ~50 мин | ⭐ |
| [s02e02](../season-02-st-pancras/s02e02-read-aloud/) — Таблица, которую читают вслух | таблица — это связи, а не клетки: `caption`, `thead`, `th scope` | `bradshaw.html` | ~60 мин | ⭐⭐ |
| [s02e03](../season-02-st-pancras/s02e03-a-form-without-code/) — Форма без единой строки кода | подписи, типы полей, встроенная проверка браузера | `search.html` | ~55 мин | ⭐⭐ |
| [s02e04](../season-02-st-pancras/s02e04-what-the-proofreader-hears/) — Что слышит корректор | доступность — следствие тегов, а не надстройка над ними | `bradshaw.html` | ~55 мин | ⭐⭐ |
| [s02e05](../season-02-st-pancras/s02e05-where-the-value-comes-from/) — Откуда берётся итоговое значение | каскад — важность, специфичность, порядок; наследование | `bradshaw.css` | ~60 мин | ⭐⭐ |
| [s02e06](../season-02-st-pancras/s02e06-a-box-wider-than-written/) — Коробка, которая шире, чем написано | блочная модель, border-box, схлопывание полей, логические стороны | `bradshaw.css` | ~60 мин | ⭐⭐ |
| [s02e07](../season-02-st-pancras/s02e07-a-row-that-decides/) — Ряд, который сам решает | Flexbox — ряд, перенос, зазор вместо полей | `bradshaw.css` | ~65 мин | ⭐⭐⭐ |
| [s02e08](../season-02-st-pancras/s02e08-a-grid-that-counts/) — Макет, где у мест есть имена | Grid — области с именами, две оси сразу, зазор, выравнивание | `bradshaw.css` | ~65 мин | ⭐⭐⭐ |
| [s02e09](../season-02-st-pancras/s02e09-where-rem-comes-from/) — Откуда берётся rem | единицы — кегль, знак, доля окна; шкала; clamp; мера строки | `bradshaw.css` | ~55 мин | ⭐⭐ |
| [s02e10](../season-02-st-pancras/s02e10-when-to-change-the-layout/) — Когда менять раскладку | медиазапросы, «сперва узкое», перелом по содержимому, печать | `bradshaw.css` | ~60 мин | ⭐⭐ |
| [s02e11](../season-02-st-pancras/s02e11-the-dark-setting/) — Тёмный набор | палитра, prefers-color-scheme, коэффициент контраста, не только цвет | `bradshaw.css` | ~60 мин | ⭐⭐ |
| [s02e12](../season-02-st-pancras/s02e12-the-template-that-prints/) — Образец, который печатает полосу | шаблон ERB — данные отдельно, образец отдельно | `bradshaw.html.erb` | ~90 мин | ⭐⭐⭐ |

---

## Season 3 — Нью-Йорк · JavaScript

серий: 10 · время: 11 ч 00 мин · проверок: 154 (не измерены без браузера: s03e04, s03e09)

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s03e01](../season-03-manhattan/s03e01-an-improvement-not-a-foundation/) — Улучшение, а не основание | скрипт улучшает то, что уже работает; модуль ES | `telegraph.html` + `telegraph.js` | ~55 мин | ⭐ |
| [s03e02](../season-03-manhattan/s03e02-a-tree-not-a-string/) — Дерево, а не текст | дерево документа — узлы, а не строка разметки | `telegraph.js` | ~60 мин | ⭐⭐ |
| [s03e03](../season-03-manhattan/s03e03-an-event-bubbles/) — Событие всплывает | события, объект события, всплытие, делегирование | `telegraph.js` | ~60 мин | ⭐⭐ |
| [s03e04](../season-03-manhattan/s03e04-a-form-with-two-ways/) — Форма, у которой два пути | отправка формы, проверка на месте, доступное сообщение об ошибке | `telegraph.js` | ~65 мин | ⭐⭐⭐ |
| [s03e05](../season-03-manhattan/s03e05-state-in-one-place/) — Состояние в одном месте | модули ES; состояние отдельно от отрисовки | `state.js` + `render.js` + `telegraph.js` | ~70 мин | ⭐⭐⭐ |
| [s03e06](../season-03-manhattan/s03e06-a-promise/) — Обещание | обещания, async/await, отказы, срок ожидания, параллельность | `office.js` | ~65 мин | ⭐⭐⭐ |
| [s03e07](../season-03-manhattan/s03e07-a-request-on-the-wire/) — Запрос по проводу | fetch, коды ответа, отмена, повтор без задвоения | `office.js` | ~70 мин | ⭐⭐⭐ |
| [s03e08](../season-03-manhattan/s03e08-someone-elses-text/) — Чужой текст | данные — не разметка; <template>, textContent, список разрешённого | `render.js` | ~60 мин | ⭐⭐⭐ |
| [s03e09](../season-03-manhattan/s03e09-an-element-of-your-own/) — Свой элемент | свой тег и его жизненный цикл; живая область; фокус читателя | `elements.js` | ~80 мин | ⭐⭐⭐⭐ |
| [s03e10](../season-03-manhattan/s03e10-a-register-that-survives-a-reload/) — Реестр, который переживает перезагрузку | адрес как состояние — URLSearchParams, pushState, popstate | `address.js` | ~75 мин | ⭐⭐⭐ |

---

## Season 4–8 — Rails 8

Не написаны. Артефакты: `ledger`, `signal_box`, `dispatch`, `keyring`, `crimson`.
