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

## Season 4 — Лондон, Сеймур-стрит · схема и Active Record

серий: 10 · время: 10 ч 55 мин · проверок: 0 (не измерены без браузера: s04e01, s04e02, s04e03, s04e04, s04e05, s04e06, s04e07, s04e08, s04e09, s04e10)

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s04e01](../season-04-seymour-street/s04e01-a-ledger-that-knows-its-shape/) — Ведомость, которая знает свою форму | миграция и схема; форма ведомости объявляется, а не подразумевается | `db/migrate/*` | ~60 мин | ⭐⭐ |
| [s04e02](../season-04-seymour-street/s04e02-a-type-that-does-not-lie/) — Тип, который не врёт | типы столбцов; деньги целым числом; день против момента; умолчание в базе | `db/migrate/*` | ~55 мин | ⭐⭐ |
| [s04e03](../season-04-seymour-street/s04e03-a-record/) — Запись | Active Record как объект — new/save/save!, валидации, что изменилось | `app/models/*.rb` | ~60 мин | ⭐⭐ |
| [s04e04](../season-04-seymour-street/s04e04-uniqueness-with-an-index-behind-it/) — Уникальность, за которой стоит индекс | уникальность; чего не умеет validates :uniqueness; уникальный индекс | `db/migrate/*`, `app/models/company.rb` | ~65 мин | ⭐⭐⭐ |
| [s04e05](../season-04-seymour-street/s04e05-a-link-that-leaves-no-orphans/) — Связь, которая не оставляет сирот | belongs_to и has_many; внешний ключ в схеме; dependent | `db/migrate/*`, `app/models/*` | ~60 мин | ⭐⭐⭐ |
| [s04e06](../season-04-seymour-street/s04e06-an-obligation-between-two/) — Обязательство между двумя | многие ко многим через свою ведомость; составной уникальный индекс | `db/migrate/*`, `app/models/leg.rb` | ~65 мин | ⭐⭐⭐ |
| [s04e07](../season-04-seymour-street/s04e07-a-question-to-the-ledger/) — Вопрос к ведомости | отбор как кусок запроса; ленивость; N+1 и как его не делать | `app/models/*.rb` | ~70 мин | ⭐⭐⭐ |
| [s04e08](../season-04-seymour-street/s04e08-a-condition-the-base-checks/) — Условие, проверенное базой | CHECK, частичный индекс, enum — и что из этого гарантия | `db/migrate/*`, `app/models/leg.rb` | ~60 мин | ⭐⭐⭐ |
| [s04e09](../season-04-seymour-street/s04e09-all-or-nothing/) — Всё или ничего | проводка; повтор, который не удваивает; блокировка перед решением | `db/migrate/*`, `app/models/settlement.rb` | ~70 мин | ⭐⭐⭐⭐ |
| [s04e10](../season-04-seymour-street/s04e10-an-index-that-will-not-lay/) — Индекс, который не ложится | миграция на живых данных: порядок шагов, проход порциями, перезапуск | `db/migrate/*` | ~90 мин | ⭐⭐⭐⭐⭐ |

---

## Season 5 — Дерби · маршруты, контроллеры, Hotwire

серий: 11 · время: 12 ч 00 мин · проверок: 0 (не измерены без браузера: s05e01, s05e02, s05e03, s05e04, s05e05, s05e06, s05e07, s05e08, s05e09, s05e10, s05e11)

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s05e01](../season-05-derby/s05e01-a-route-is-a-promise/) — Маршрут — это обещание | маршрут и контроллер; `resources` и `rails routes`; 404 там, где маршрута нет | `config/routes.rb`, `app/controllers/companies_controller.rb`, `app/views/companies/*` | ~60 мин | ⭐⭐ |
| [s05e02](../season-05-derby/s05e02-one-decision-in-one-place/) — Одно решение в одном месте | параметры маршрута; адрес по коду; ограничение на параметр; `before_action` | `config/routes.rb`, `app/controllers/companies_controller.rb`, `app/models/company.rb` | ~55 мин | ⭐⭐ |
| [s05e03](../season-05-derby/s05e03-a-page-read-aloud/) — Страница, которую читают вслух | представление: макет, частичные шаблоны, помощники; разметка из сезона 2 | `app/views/*`, `app/helpers/*`, `app/controllers/companies_controller.rb` | ~65 мин | ⭐⭐⭐ |
| [s05e04](../season-05-derby/s05e04-a-form-that-comes-back/) — Форма, которая возвращается | форма: `form_with`, сильные параметры, 303 и 422, отказ базы словами | `app/controllers/consignments_controller.rb`, `app/views/consignments/*`, `config/routes.rb` | ~70 мин | ⭐⭐⭐ |
| [s05e05](../season-05-derby/s05e05-an-edit-and-a-refusal/) — Правка и отказ | правка и удаление: `edit`, `update`, `destroy`; отказ с причиной; 303 после `DELETE` | `app/controllers/companies_controller.rb`, `app/views/companies/*`, `config/routes.rb` | ~60 мин | ⭐⭐⭐ |
| [s05e06](../season-05-derby/s05e06-through-your-own-book/) — Через свою книгу | вложенные маршруты; поиск в пределах родителя; чужая запись через свою книгу — 404 | `config/routes.rb`, `app/controllers/consignments_controller.rb`, `app/views/consignments/*` | ~60 мин | ⭐⭐⭐ |
| [s05e07](../season-05-derby/s05e07-a-page-that-does-not-reload/) — Страница, которая не перезагружается | Turbo Drive: переход без перезагрузки, снимок в кеше, постоянный элемент | `app/views/layouts/application.html.erb` | ~55 мин | ⭐⭐⭐ |
| [s05e08](../season-05-derby/s05e08-a-part-that-answers-for-itself/) — Кусок, который отвечает за себя | Turbo Frames: кусок страницы со своим адресом; ленивый фрейм; правка на месте | `app/views/companies/*`, `app/views/settlements/*`, `app/controllers/settlements_controller.rb`, `config/routes.rb` | ~65 мин | ⭐⭐⭐⭐ |
| [s05e09](../season-05-derby/s05e09-where-they-are-waiting/) — Туда, где ждут | Turbo Streams: ответ формы — действия над страницей; цели, которые есть; ответ без Turbo | `app/controllers/payments_controller.rb`, `app/views/payments/*`, `app/views/settlements/*`, `config/routes.rb` | ~75 мин | ⭐⭐⭐⭐ |
| [s05e10](../season-05-derby/s05e10-where-turbo-is-not-enough/) — Где Turbo мало | Stimulus: поведение у разметки; цели, значения, действия; подключение после визита | `app/javascript/controllers/money_controller.js`, `app/views/consignments/_form.html.erb` | ~65 мин | ⭐⭐⭐⭐ |
| [s05e11](../season-05-derby/s05e11-an-answer-the-telegraph-understands/) — Ответ, который понимает телеграф | форматы ответа: HTML, JSON, CSV; `Accept` и расширение; 406; отказ в формате спрашивающего | `app/controllers/*`, `app/views/**/*.jbuilder`, `app/views/settlements/index.html.erb` | ~90 мин | ⭐⭐⭐⭐⭐ |

---

## Season 6 — Владивосток · фон, кеш, каналы, интеграции

серий: 11 · время: 12 ч 25 мин · проверок: 0 (не измерены без браузера: s06e01, s06e02, s06e03, s06e04, s06e05, s06e06, s06e07, s06e08, s06e09, s06e10, s06e11)

| Серия | Концепт | Артефакт | ⏱ | |
|---|---|---|---|---|
| [s06e01](../season-06-vladivostok/s06e01-a-job-is-a-note/) — Задача — это записка | задача в фоне: Active Job, `perform_later`; в записке ссылка на запись, а не её копия | `app/jobs/dispatch_job.rb`, `app/controllers/telegrams_controller.rb`, `config/routes.rb` | ~60 мин | ⭐⭐ |
| [s06e02](../season-06-vladivostok/s06e02-a-queue-that-outlives-the-night/) — Очередь, которая переживает ночь | очередь — таблица: Solid Queue, готовые, отложенные, взятые; своя очередь, приоритет, отложенный запуск | `app/jobs/dispatch_job.rb`, `app/models/telegraph_line.rb`, `config/queue.yml` | ~65 мин | ⭐⭐⭐ |
| [s06e03](../season-06-vladivostok/s06e03-when-the-line-breaks/) — Когда рвётся линия | повтор после сбоя: `retry_on`, `discard_on`, пауза, которая растёт, предел попыток; провал, который видно | `app/jobs/dispatch_job.rb`, `app/models/telegraph_line.rb` | ~65 мин | ⭐⭐⭐ |
| [s06e04](../season-06-vladivostok/s06e04-twice-as-once/) — Дважды — как один раз | идемпотентность: задача дважды — эффект один; ключ — сама вещь, а не конверт; индекс держит, транзакция связывает | `app/jobs/disburse_job.rb`, `app/models/acceptance.rb`, `db/migrate/*` | ~75 мин | ⭐⭐⭐⭐ |
| [s06e05](../season-06-vladivostok/s06e05-someone-elses-line/) — Чужая линия | внешний источник: HTTP с пределами ожидания, молчание как обрыв, ключ повтора для чужой стороны, справка «не наша» как ответ | `app/models/telegraph_line.rb` | ~70 мин | ⭐⭐⭐⭐ |
| [s06e06](../season-06-vladivostok/s06e06-a-receipt-from-outside/) — Квитанция снаружи | входящий вызов: подпись HMAC над сырым телом и временем, 202 и работа в фоне, повтор той же квитанции, отказ словами | `app/controllers/receipts_controller.rb`, `config/routes.rb` | ~65 мин | ⭐⭐⭐⭐ |
| [s06e07](../season-06-vladivostok/s06e07-a-copy-that-knows-it-is-stale/) — Копия, которая знает, что устарела | кеш: `Rails.cache` и Solid Cache, ключ с версией книг, копия строки и `touch` | `app/models/delivery.rb`, `app/models/acceptance.rb`, `app/models/disbursement.rb`, `app/views/deliveries/_delivery.html.erb`, `config/environments/test.rb` | ~65 мин | ⭐⭐⭐ |
| [s06e08](../season-06-vladivostok/s06e08-the-page-you-already-have/) — Страница, которая у тебя уже есть | HTTP-кеш: `ETag`, `Last-Modified`, `304 Not Modified`, `fresh_when`; копия у читающего и `Cache-Control` | `app/controllers/payouts_controller.rb` | ~55 мин | ⭐⭐⭐ |
| [s06e09](../season-06-vladivostok/s06e09-news-that-comes-by-itself/) — Новость, которая приходит сама | каналы: Turbo Streams по Action Cable, трансляция из работника после коммита, подписанное имя потока, Solid Cable | `app/models/delivery.rb`, `app/views/board/show.html.erb`, `config/cable.yml` | ~65 мин | ⭐⭐⭐⭐ |
| [s06e10](../season-06-vladivostok/s06e10-one-day-under-two-dates/) — Один день под двумя датами | расписание: повторяющиеся задачи Solid Queue, часовой пояс в расписании и в счёте, два календаря, одна сводка на день | `app/jobs/daily_report_job.rb`, `app/models/acceptance.rb`, `config/recurring.yml`, `db/migrate/*` | ~70 мин | ⭐⭐⭐⭐ |
| [s06e11](../season-06-vladivostok/s06e11-the-whole-line-under-strain/) — Вся линия под нагрузкой | сверка с чужой книгой: клиент с пределами, задача по расписанию, переплата с ключом; приёмка сезона под нагрузкой | `app/jobs/reconcile_job.rb`, `app/models/treasury_book.rb`, `db/migrate/*`, `config/recurring.yml` | ~90 мин | ⭐⭐⭐⭐⭐ |

---

## Season 7–8 — Rails 8

Не написаны. Артефакты: `keyring`, `crimson`.
