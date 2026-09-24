# CRIMSON RAILS — s05e03, проверка.
#
# Страницу читают вслух — человек в счётной конторе и машина для тех, кто не
# видит. Поэтому проверяется то, что слышно, а не то, что написано в шаблоне:
# ответ разбирается так же, как его разберёт браузер, и спрашивается о
# документе — на каком он языке, где в нём главное, что за таблица и что в
# каждой её клетке.

require_relative "../../support/check.rb"

class PageTest < Crimson::Test
  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
  end

  def settle(company, period, pence, state: :pending)
    Settlement.create!(company: company, period: period, pence: pence, state: state)
  end

  # ─── документ ───────────────────────────────────────────────────────────

  def test_the_page_speaks_russian
    [path(:companies), path(:company, @mid)].each do |address|
      get address
      assert_match(/\Aru\b/, page.at_css("html")&.[]("lang").to_s,
                   "Страница #{address} не говорит, на каком она языке. Машина, которая " \
                   "читает вслух, прочтёт русский текст английским произношением.")
    end
  end

  def test_one_main_heading_inside_the_main_part
    [path(:companies), path(:company, @mid)].each do |address|
      get address
      assert_equal 1, page.css("h1").size, "На странице #{address} заголовков первого уровня не один."
      assert_equal 1, page.css("main").size,
                   "На странице #{address} нет одной главной части. По ней читающий вслух " \
                   "пропускает шапку и сразу слышит содержание."
      refute_nil page.at_css("main h1"), "Главный заголовок — вне главной части страницы."
    end
  end

  def test_the_title_names_the_page
    get path(:company, @mid)
    assert_includes page.at_css("title")&.text.to_s, "MID",
                    "Заголовок окна не называет дорогу. Двенадцать открытых вкладок с одним " \
                    "заголовком читаются вслух одинаково."
  end

  def test_the_way_to_the_registry_is_on_every_page
    [path(:companies), path(:company, @mid)].each do |address|
      get address
      nav = page.at_css("nav")
      refute_nil nav, "На странице #{address} нет навигации."
      assert_includes nav.css("a[href]").map { |node| URI(node["href"]).path }, path(:companies),
                      "Из навигации страницы #{address} не попасть в реестр. Путь, общий для " \
                      "всех страниц, живёт в макете, а не в каждом шаблоне."
    end
  end

  def test_the_registry_is_a_list
    road("GNR")
    get path(:companies)
    links = page.css("a[href]").select { |node| URI(node["href"]).path.start_with?("/companies/") }
    refute_empty links
    links.each do |node|
      assert_equal "li", node.parent&.name,
                   "Дорога «#{node.text.squish}» стоит не пунктом списка. Список дорог — это " \
                   "список: читающий вслух слышит «список, пять пунктов», а не пять абзацев."
    end
  end

  # ─── таблица расчётов ───────────────────────────────────────────────────

  def test_settlements_are_a_table_with_a_caption
    settle(@mid, "1891-08", 192_240)
    get path(:company, @mid)
    refute_nil find_settlements_table,
               "Расчётов нет таблицей с подписью. Подпись говорит, о чём таблица, до того, " \
               "как прозвучит первая клетка."
  end

  def test_every_column_is_named
    settle(@mid, "1891-08", 192_240)
    get path(:company, @mid)
    table = settlements_table
    headers = table.css("thead th")
    refute_empty headers, "У таблицы нет заголовков столбцов."
    assert headers.all? { |node| node["scope"] == "col" },
           "Заголовки столбцов не объявлены заголовками столбцов (`scope=\"col\"`)."
    table.css("tbody tr").each do |row|
      assert_equal headers.size, row.css("th, td").size,
                   "В строке клеток не столько, сколько столбцов."
    end
  end

  def test_every_row_is_named_by_its_month
    settle(@mid, "1891-08", 192_240)
    settle(@mid, "1891-09", 192_240)
    get path(:company, @mid)
    names = settlements_table.css("tbody tr").map { |row| row.at_css("th[scope='row']")&.text&.squish }
    assert_equal %w[1891-08 1891-09], names,
                 "Строка таблицы не названа своим месяцем. Без заголовка строки читающий " \
                 "вслух слышит «£801 0s 0d, посчитан» и не знает, за какой это месяц."
  end

  def test_months_are_in_order
    %w[1891-09 1890-12 1891-01].each { |period| settle(@mid, period, 240) }
    get path(:company, @mid)
    names = settlements_table.css("tbody tr th[scope='row']").map { |node| node.text.squish }
    assert_equal %w[1890-12 1891-01 1891-09], names, "Месяцы идут не по порядку."
  end

  # ─── деньги ─────────────────────────────────────────────────────────────

  def test_money_is_read_in_pounds_shillings_and_pence_without_loss
    samples = [1, 11, 12, 13, 239, 240, 241, 2_879, 2_880, 192_240, 192_251]
    samples.each_with_index { |pence, index| settle(@mid, format("18%02d-01", 60 + index), pence) }
    get path(:company, @mid)

    shown = column(settlements_table, "Сумма")
    samples.zip(shown).each do |pence, text|
      found = text.to_s.match(/\A£(\d+) (\d{1,2})s (\d{1,2})d\z/)
      refute_nil found,
                 "Сумма #{pence} пенсов показана как «#{text}». Читается она фунтами, " \
                 "шиллингами и пенсами — «£3 4s 7d» — и все три части всегда на месте."
      pounds, shillings, rest = found.captures.map(&:to_i)
      assert_operator shillings, :<, 20, "Шиллингов в «#{text}» двадцать или больше: это уже фунт."
      assert_operator rest, :<, 12, "Пенсов в «#{text}» двенадцать или больше: это уже шиллинг."
      assert_equal pence, pounds * 240 + shillings * 12 + rest,
                   "«#{text}» — не #{pence} пенсов. В фунте 240 пенсов, в шиллинге 12."
    end
  end

  def test_the_state_is_said_in_words
    settle(@mid, "1891-07", 240, state: :paid)
    settle(@mid, "1891-08", 240)
    get path(:company, @mid)
    cells = column(settlements_table, "Состояние")
    assert_equal %w[оплачен посчитан], cells,
                 "Состояние расчёта названо не словом. Имена `pending` и `paid` — для кода; " \
                 "вслух их не читают."
  end

  # ─── чужой текст и пустота ──────────────────────────────────────────────

  def test_a_name_with_markup_stays_text
    lnw = road("LNW", "<b>Лондонская</b> и северо-западная")
    get path(:company, lnw)
    assert_includes main_part.text, "<b>Лондонская</b>",
                    "Название дороги потерялось или стало разметкой."
    assert_nil page.at_css("main b"),
               "Название дороги вставлено в страницу разметкой. Чужой текст остаётся " \
               "текстом (s03e08): `raw` и `html_safe` здесь — дыра, а не удобство."
  end

  def test_a_road_without_settlements_is_still_a_page
    get path(:company, @mid)
    assert_status 200
    assert_nil page.at_css("main table"),
               "У дороги без расчётов на странице пустая таблица. Таблица без строк читается " \
               "вслух как «таблица, ноль строк» — это шум, а не ответ."
  end

  private

  # Клетки столбца — по его заголовку, а не по месту: столбцы добавляются, и
  # «последний» сегодня — не последний завтра.
  def column(table, header)
    headers = table.css("thead th").map { |node| node.text.squish }
    index = headers.index(header) || flunk("У таблицы нет столбца «#{header}». Столбцы: #{headers.join(', ')}.")
    table.css("tbody tr").map { |row| row.css("th, td")[index]&.text&.squish }
  end

  def main_part
    page.at_css("main") || flunk("На странице нет главной части `<main>`: искать содержание негде.")
  end

  def find_settlements_table
    page.css("main table").find { |table| table.at_css("caption")&.text.to_s.include?("Расчёт") }
  end

  # Таблица расчётов — или объяснение, почему её нет.
  def settlements_table
    find_settlements_table || flunk(
      "На странице дороги нет таблицы расчётов с подписью «Расчёты с дорогой …». " \
      "Искать её больше не по чему: подпись — то, что говорит, о чём таблица."
    )
  end
end
