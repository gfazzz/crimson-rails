# CRIMSON RAILS — источники

## Происхождение идеи

Курс вырос из заметки **[«Crimson Rails: интерактивный курс по Ruby on
Rails»](https://eurecable.com/ideas/972)**, опубликованной на eurecable.com
3 октября 2025 года (ideas/972).

Из заметки взяты и оставлены: викторианская эпоха 1890-х, структура внутри
общества, действующая через институты, Эдисон против Теслы как спор о
централизованном и асинхронном, Ада Лавлейс и Чарльз Бэббидж, отсылка к
Кэрроллу, деление на сезоны с проектом в конце каждого.

Изменено против заметки:

- **железная дорога стала основанием, а не названием.** В заметке «rails» —
  каламбур; здесь метафора несёт объяснительную нагрузку, и каждое сравнение
  обязано что-то объяснять (CONCEPT.md, «правило метафоры»);
- **герой — вычислитель, а не сыщик.** Младший вычислитель Расчётной палаты
  железных дорог: его работа — превращать вопросы в перфокарты, то есть
  программировать. Учебная деятельность и сюжетная профессия совпадают;
- **наставник — машина.** Аналитическая машина ADA вместо человека-ментора
  предыдущих курсов школы. Помощник в реальности — модель; в сюжете он тоже
  машина, и притворяться не приходится;
- **CRIMSON RAILS — не самоназвание.** Это пометка красными чернилами в
  ведомости Палаты: перевозки, которые не сходятся в расчёте;
- **восемь сезонов вместо четырёх.** Добавлены Ruby, HTML/CSS и JavaScript;
  аутентификация вынесена из общего сезона в свой;
- **география вместо одного города.** Йокогама, Лондон, Нью-Йорк, Транссиб,
  Восточный экспресс, Чикаго — по маршруту на запад;
- **стек Rails 8.** Sidekiq и Redis из заметки заменены на Solid Queue,
  Solid Cache и Solid Cable, PostgreSQL — на SQLite: курс должен проходиться
  без внешних сервисов.

## Школа

Стандарт серии, канон разделов, требования к тестам и роль наставника
унаследованы от двух выпущенных курсов того же автора:

- [OPERATION MOONLIGHT](https://github.com/gfazzz/moonlight-course) — язык C,
  80 серий, MIT;
- [KERNEL SHADOWS](https://github.com/gfazzz/kernel-shadows) — Linux, сети,
  безопасность, 101 серия, GPL v3.

---

# Книги

Список — основа для `theory.md` серий: раздел «Ссылки и AI-usage» каждой серии
берёт источники отсюда, а `docs/RESOURCES.md` собирается из `theory.md`
автоматически. ✓ — есть в библиотеке автора.

## Ruby как язык

| Книга | |
|---|---|
| Rappin N., Thomas D. — **Programming Ruby 3.3** (5th ed., 2024) — «кирка», основной справочник по современному Ruby | ✓ |
| Flanagan D., Matsumoto Y. — **The Ruby Programming Language** (2008); рус. Флэнаган, Мацумото — «Язык программирования Ruby» (2011) — язык из первых рук | ✓ |
| Black D. A. — **The Well-Grounded Rubyist** (3rd ed., 2019) — объектная модель и `self` без магии | ✓ |
| Olsen R. — **Eloquent Ruby** (2011) — как писать на Ruby, а не на Java с двоеточиями | ✓ |
| Perrotta P. — **Metaprogramming Ruby** (2nd ed., 2014) — `method_missing`, `define_method`, почему `has_many` не магия | ✓ |
| Metz S. — **Practical Object-Oriented Design in Ruby** (2nd ed., 2018); рус. «Ruby. Объектно-ориентированное проектирование» (2017) | ✓ |
| Grimm A. — **Confident Ruby** (2013), **Exceptional Ruby** (2011) — сообщения об ошибках и работа с исключениями | ✓ |
| Jones P. — **Effective Ruby** (2014); Evans J. — **Polished Ruby Programming** (2021) — идиомы и края | ✓ |
| Shaughnessy P. — **Ruby Under a Microscope** (2014) — что делает интерпретатор; для `theory.md` глубоких серий | ✓ |
| Фултон Х. — **Путь Ruby** (2015) — большой русский справочник рецептов | ✓ |

## Rails

| Книга | |
|---|---|
| Ruby S., Thomas D. — **Agile Web Development with Rails 7** (2024) — каноническое введение; для Rails 8 сверять с гайдами | ✓ |
| Hartl M. — **Ruby on Rails Tutorial** (7th ed., 2022); рус. «Ruby on Rails для начинающих» (2017) | ✓ |
| Copeland D. B. — **Sustainable Web Development with Ruby on Rails** (2020) — как приложение живёт годами, а не до релиза | ✓ |
| Fernandez O. — **The Rails 5 Way** (2017); рус. Фернандес — «Путь Rails» (2009) — справочник по внутренностям фреймворка | ✓ |
| Dementyev V. — **Layered Design for Ruby on Rails Applications** (2023); рус. Дементьев — «Проектирование приложений Ruby on Rails слой за слоем» — куда девать логику, когда модель распухла | ✓ |
| Pytel C., Saleh T. — **Rails AntiPatterns** (2010) — источник красных анти-паттернов для серий | ✓ |
| Marshall K. и др. — **Pro Active Record** (2007) — устарела по API, но хороша про отображение схемы на объекты | ✓ |
| **Ruby on Rails Guides** — guides.rubyonrails.org — единственный источник, актуальный для Rails 8; книги по 7 и раньше сверять с ним | — |

## Базы данных и схема

Сезон 4 держится на этих источниках: Rails Guides объясняют, **как**, остальное —
**почему** и **что будет на миллионе строк**.

| Книга | |
|---|---|
| Kleppmann M. — **Designing Data-Intensive Applications** (2017); рус. Клеппман — «Высоконагруженные приложения» (2018) — глава 7 про транзакции, изоляцию и блокировки | ✓ |
| Ambler S., Sadalage P. — **Refactoring Databases: Evolutionary Database Design** (2006) — откуда вообще взялась мысль, что схему меняют маленькими обратимыми шагами | ✓ |
| Sadalage P. — **Recipes for Continuous Database Integration** (2007) — миграции в выкатке, а не в голове | — |
| Karwin B. — **SQL Antipatterns** (2010; 2nd ed. 2022) — источник красных анти-паттернов сезона: EAV, «ключ без ключа», деньги дробным числом | ✓ |
| Celko J. — **SQL for Smarties** (5th ed., 2014) — что база умеет считать сама, вместо того чтобы отдавать строки в Ruby | ✓ |
| **PostgreSQL Documentation** — Constraints, Indexes, Concurrency Control, ALTER TABLE, Building Indexes Concurrently | — |
| **SQLite Documentation** — CREATE TABLE (раздел CHECK), Partial Indexes, Datatypes In SQLite | — |
| **strong_migrations** (гем, github.com/ankane/strong_migrations) — список опасных миграций с объяснением, чем именно они опасны; читается как конспект `s04e10` | — |

## HTML и CSS

| Книга | |
|---|---|
| Meyer E. — **CSS Pocket Reference** (5th ed., 2018) — рабочий справочник сезона 2 | ✓ |
| Meyer E. — **Cascading Style Sheets: The Definitive Guide** (2nd ed., 2004) — издание старое, но каскад, специфичность и блочная модель с тех пор не менялись | ✓ |
| Gasston P. — **The Book of CSS3** (2nd ed., 2014) — медиазапросы, единицы, современные селекторы | ✓ |
| Boehm A., Ruvalcaba Z. — **Murach's HTML5 and CSS3** (4th ed., 2018) — практический курс с разбором раскладок | ✓ |
| MacDonald M. — **HTML5: The Missing Manual** (2nd ed., 2014) — семантические элементы и формы | ✓ |
| Meyer J. — **The Essential Guide to HTML5** (2022) | ✓ |
| Robbins J. N. — **HTML5 Pocket Reference** (5th ed., 2013) | ✓ |
| Robson E., Freeman E. — **Head First HTML and CSS**; рус. «Изучаем HTML, XHTML и CSS» | ✓ |
| Сидельников Г. — **Наглядный CSS** (2021) | ✓ |
| **MDN Web Docs** — developer.mozilla.org | — |
| **HTML Living Standard** — html.spec.whatwg.org — первоисточник по семантике элементов, нужен там, где MDN упрощает | — |
| **WAI-ARIA Authoring Practices** — w3.org/WAI/ARIA/apg — для серии про таблицу расписания | — |
| Meyer E., Weyl E. — **CSS: The Definitive Guide** (4th ed., 2017) — в библиотеке только 2-е издание; Grid и Flexbox есть лишь в 4-м, стоит добрать к пилоту сезона 2 | — |
| Pickering H. — **Inclusive Components** (2018) — доступность как следствие правильных тегов; стоит добрать | — |
| Andrew R. — **The New CSS Layout** (2017) — автор спецификации о том, зачем Flexbox и Grid устроены так; серии s02e06–s02e08 | — |
| **WCAG 2.2** — w3.org/TR/WCAG22 и разделы Understanding — пороги контраста и правило «не только цветом»; серии s02e04, s02e10, s02e11 | — |
| **WAI Web Accessibility Tutorials** — w3.org/WAI/tutorials — изображения, таблицы, формы; серии s02e02–s02e04 | — |
| Marcotte E. — **Responsive Web Design** (A List Apart, 2010) — статья, с которой начались медиазапросы; серия s02e10 | — |
| Bringhurst R. — **The Elements of Typographic Style** (4th ed., 2012) — откуда мера строки в 45–75 знаков; серия s02e09 | — |
| Itten J. — **Kunst der Farbe**; рус. «Искусство цвета» — почему одинаковая светлота не выглядит одинаковой; серия s02e11 | — |

## JavaScript

| Книга | |
|---|---|
| Flanagan D. — **JavaScript: The Definitive Guide** (7th ed., 2020) — основной справочник сезона 3 | ✓ |
| Simpson K. — **You Don't Know JS** (2016, 6 книг); рус. «Вы пока ещё не знаете JS» (2022) — замыкания, область видимости, `this` | ✓ |
| Хавербеке М. — **Выразительный JavaScript** (3-е изд., 2019) | ✓ |
| Крокфорд Д. — **JavaScript. Сильные стороны** (2012), **Как устроен JavaScript** (2019) | ✓ |
| Rauschmayer A. — **JavaScript for Impatient Programmers** (2022) — модули ES и современный синтаксис | ✓ |
| Resig J., Bibeault B., Maras J. — **Secrets of the JavaScript Ninja** (2nd ed., 2016) — события и всплытие | ✓ |
| Zakas N. — **Professional JavaScript for Web Developers** (3rd ed.); рус. Закас (2015) | ✓ |
| Freeman E., Robson E. — **Head First JavaScript Programming** (2nd ed., 2024) | ✓ |
| Свекис Л. Л., ван Путтен М., Персиваль Р. — **JavaScript с нуля до профи** (2023) | ✓ |
| **Hotwire Handbook** — hotwired.dev — граница «где свой JS не писать»; Turbo Drive и история, жизненный цикл контроллера Stimulus; серии s03e09, s03e10 | — |
| **MDN Web Docs** — developer.mozilla.org — основной справочник по DOM, событиям, `fetch`, `<template>`, своим элементам, `URL` и History API | — |
| **DOM Living Standard** — dom.spec.whatwg.org — первоисточник по событиям и всплытию, нужен там, где MDN упрощает; серия s03e03 | — |
| **OWASP Cross Site Scripting Prevention Cheat Sheet** — cheatsheetseries.owasp.org — правила по местам вставки: содержимое, атрибут, адрес; серия s03e08 | — |
| **Rails Guides: Securing Rails Applications** — разделы про XSS и `html_safe`; серия s03e08 | — |
| **WAI-ARIA Authoring Practices: Live Regions** — w3.org/WAI/ARIA/apg — живая область и фокус; серии s03e04, s03e09 | — |
| **RFC 9110 (HTTP Semantics)** — коды ответа и идемпотентность; серия s03e07 | — |

## HTTP, API, интеграции

| Книга | |
|---|---|
| Gourley D., Totty B. — **HTTP: The Definitive Guide** (2002) — коды ответов, кеширование, условные запросы; сезон 5 | ✓ |
| Richardson L., Ruby S. — **RESTful Web Services** (2007) — ресурс и маршрут как понятия, а не как соглашение Rails | ✓ |
| Lauret A. — **The Design of Web APIs** (2019) — сезон 6: идемпотентность, повторы, версии | ✓ |
| **Rails Guides: Rails Routing from the Outside In; Action Controller Overview; Layouts and Rendering; Action View Form Helpers** — основа сезона 5 | — |
| **Turbo Handbook** — turbo.hotwired.dev — Drive, Frames, Streams; коды 303 и 422, заголовок `Turbo-Frame`; серии s05e07–s05e09 | — |
| **Stimulus Handbook** — stimulus.hotwired.dev — контроллеры, цели, значения; серия s05e10 | — |
| **turbo-rails** (гем, github.com/hotwired/turbo-rails) — помощники `turbo_frame_tag` и `turbo_stream`; как сервер распознаёт запрос фрейма | — |
| **jbuilder** (гем, github.com/rails/jbuilder) — README; серия s05e11 | — |
| **RFC 9110 (HTTP Semantics)** — 12.5.1 `Accept`, 15.4.4 `303 See Other`, 15.5.7 `406`, 15.5.21 `422`; сезон 5 целиком | — |
| **RFC 6266** — `Content-Disposition`; серия s05e11 | — |
| **WAI Tables Tutorial**, **WAI-ARIA Live Regions** — w3.org/WAI — таблица и живая область в шаблонах Rails; серии s05e03, s05e09 | — |
| **OWASP Authorization Cheat Sheet** (раздел IDOR) — cheatsheetseries.owasp.org — чужая запись через свою книгу; серия s05e06 | — |

## Ремесло, тесты, рефакторинг

| Книга | |
|---|---|
| Бек К. — **Экстремальное программирование. Разработка через тестирование** — почему красный тест пишется первым | ✓ |
| Paranj B. — **Test Driven Development in Ruby** (2017) | ✓ |
| Fields J., Harvie S., Fowler M. — **Refactoring: Ruby Edition** (2009) | ✓ |
| Ferris J., Ward H. — **Ruby Science** (2013) — запахи в коде на Rails и что с ними делать | ✓ |
| Макконнелл С. — **Совершенный код** (2-е изд.) | ✓ |
| Мартин Р. — **Чистый код**, **Чистая архитектура** | ✓ |
| Петцольд Ч. — **Код. Тайный язык информатики** (2019) — книга, которая начинается с телеграфных реле; для курса про телеграф вдоль полотна — прямое попадание | ✓ |
| Fowler M. — **Patterns of Enterprise Application Architecture** (2002) — Template View и Transform View, развилка финала сезона 2; дальше — Active Record в сезоне 4 | — |

---

# Источники сеттинга

Ни одна из этих книг не нужна, чтобы пройти курс. Они нужны, чтобы его писать:
хронология, детали и терминология сезонов берутся отсюда, а не из воображения.

**Главный долг — Сидни Падуа.** «Невероятные приключения Лавлейс и Бэббиджа.
(Почти) правдивая история первого компьютера» (Sydney Padua, *The Thrilling
Adventures of Lovelace and Babbage*, 2015) — комикс, в котором Аналитическая
машина всё-таки построена, а сноски точнее, чем у иных монографий. Оттуда взято
единственное допущение курса (машина работает) и наставник ADA: машина, которая
отвечает буквально и не притворяется человеком.

| Книга | Для чего |
|---|---|
| Padua S. — **The Thrilling Adventures of Lovelace and Babbage** (2015); рус. «Невероятные приключения Лавлейс и Бэббиджа» | Аналитическая машина, ADA, тон курса |
| Wolmar C. — **Blood, Iron, and Gold: How the Railroads Transformed the World** (2009) | общая рама: как дороги переделали мир, включая Японию и США |
| Wolmar C. — **To the Edge of the World: The Story of the Trans-Siberian Railway** (2013) | сезон 6, стройка с 1891 года |
| Schivelbusch W. — **The Railway Journey: The Industrialization of Time and Space in the 19th Century** (1977); рус. Шивельбуш — «Железнодорожное путешествие» | как дорога изменила восприятие времени и расстояния — идейная основа всего курса |
| Galison P. — **Einstein's Clocks, Poincaré's Maps** (2003) | синхронизация времени; сезон 8 и часовые пояса 1883 года |
| Jonnes J. — **Empires of Light: Edison, Tesla, Westinghouse** (2003) | сезон 3, война токов |
| Larson E. — **The Devil in the White City** (2003); рус. «Дьявол в белом городе» | сезон 8, Чикаго и выставка 1893 года |
| **Bradshaw's Railway Guide** (выпуски 1839–1961) | первоисточник для артефакта сезона 2: как выглядит настоящее расписание |
| Верн Ж. — **Вокруг света за восемьдесят дней** (1873) | маршрут курса — половина пути Филеаса Фогга, в обратную сторону |
| Кэрролл Л. — **Сквозь зеркало и что там увидела Алиса** (1871), глава III | сцена в вагоне; отсылка к Алисе из исходной идеи |

**Расчётная палата железных дорог** (Railway Clearing House, Сеймур-стрит,
Лондон, 1842–1963) — не выдумка. Она действительно разносила по счетам каждую
сквозную перевозку королевства силами нескольких тысяч клерков и была, по сути,
крупнейшим вычислительным центром мира до появления вычислительных центров.
Материалы по ней — в архивах National Railway Museum (Йорк) и The National
Archives (Кью); их надо поднять до пилота сезона 4.

---

## Лицензия

Курс — MIT. Книги и справочники в списке принадлежат своим правообладателям и
приводятся как рекомендации к чтению.
