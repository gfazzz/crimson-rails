# CRIMSON RAILS — s05e01, проверка.
#
# Маршрут — обещание: запрос по этому адресу дойдёт до этого решения. Поэтому
# проверяется две вещи и только они. Таблица маршрутов: куда ведёт адрес и
# есть ли там кому ответить. И ответ: код, тип и то, о чём страница, — а не
# то, какие теги стоят в шаблоне.
#
# Адреса дорог берутся у помощников маршрутов, а не пишутся руками: в
# следующей серии дорогу начнут звать кодом, и проверка этой серии обязана
# остаться верной.

require_relative "../../support/check.rb"

class RoutesTest < Crimson::Test
  def setup
    wipe!
  end

  # ─── таблица маршрутов ──────────────────────────────────────────────────

  def test_the_list_is_routed_to_index
    assert_equal "companies#index", route(:get, "/companies"),
                 "GET /companies не ведёт в companies#index. Список дорог — первое обещание " \
                 "окна; объявляется оно в config/routes.rb."
  end

  def test_one_road_is_routed_to_show
    address = path(:company, road("MID"))
    assert_equal "companies#show", route(:get, address),
                 "GET #{address} не ведёт в companies#show."
  end

  def test_the_root_is_the_registry
    assert_equal "companies#index", route(:get, "/"),
                 "Корень не ведёт в реестр. Контора открывает окно с адреса «/», и без " \
                 "`root` получает страницу-заглушку Rails или 404."
  end

  def test_every_route_has_someone_to_answer
    promised = Rails.application.routes.routes.filter_map do |item|
      controller = item.defaults[:controller]
      next if controller.nil? || controller.start_with?("rails/", "action_", "active_", "turbo/")

      [item.verb, item.path.spec.to_s.delete_suffix("(.:format)"), controller, item.defaults[:action]]
    end
    refute_empty promised, "В таблице маршрутов нет ни одного своего маршрута."

    promised.each do |verb, path, controller, action|
      klass = "#{controller.camelize}Controller".safe_constantize
      refute_nil klass, "Маршрут #{verb} #{path} ведёт в #{controller}, а такого контроллера нет."
      assert_includes klass.action_methods, action,
                      "Маршрут #{verb} #{path} обещает #{controller}##{action}, а такого действия " \
                      "нет. Маршрут — обещание: объявлять надо то, что окно умеет, и ничего " \
                      "сверх. `resources` без `only:` объявляет семь."
    end
  end

  def test_the_routes_have_names
    mid = road("MID")
    assert_equal "/companies", path(:companies)
    assert_equal "/companies/#{mid.to_param}", path(:company, mid)
  end

  def test_where_there_is_no_route_the_answer_is_404
    get "/signal-box"
    assert_status 404, "Адрес, которого нет в таблице, обязан давать 404."
    delete "/companies"
    assert_status 404, "Удалять весь реестр одним запросом никто не обещал — значит 404."
  end

  # ─── список ─────────────────────────────────────────────────────────────

  def test_the_list_is_a_page
    road("MID")
    get "/companies"
    assert_status 200
    assert_equal "text/html", media_type
  end

  def test_an_empty_registry_is_an_answer_not_an_error
    get "/companies"
    assert_status 200,
                  "Пустой реестр — это ответ, а не ошибка. Пустой список отвечает 200; 404 — " \
                  "это когда нет того, о чём спросили, а спросили о списке."
  end

  def test_every_road_is_on_the_list
    roads = %w[NER GNR MID MDL LNW].map { |code| road(code) }
    get "/companies"
    assert_equal roads.map { |item| path(:company, item) }.sort, linked_roads.sort,
                 "Список дорог неполон или ведёт не туда. У каждой дороги — ссылка на её " \
                 "страницу, и больше ни на что."
  end

  def test_the_list_is_in_code_order
    # Имена нарочно идут в другом порядке, чем коды: иначе список «по имени»
    # и список «по коду» не отличить.
    roads = { "NER" => "Дорога А", "GNR" => "Дорога Д", "MID" => "Дорога Б",
              "MDL" => "Дорога В", "LNW" => "Дорога Г" }.map { |code, name| road(code, name) }
    get "/companies"
    assert_equal roads.sort_by(&:code).map { |item| path(:company, item) }, linked_roads,
                 "Дороги стоят не по коду. Так они стоят в книгах Палаты, и так контора ищет " \
                 "их глазами; порядок записей в базе — не порядок, а случайность."
  end

  def test_a_link_leads_to_its_road
    %w[GNR MID NER].each { |code| road(code) }
    get "/companies"
    links = page.css("a[href]").to_h { |node| [node.text.squish, URI(node["href"]).path] }

    %w[GNR MID NER].each do |code|
      refute_nil links[code], "На списке нет ссылки с кодом #{code}."
      get links[code]
      assert_status 200
      assert_includes texts("h1"), code,
                      "Ссылка «#{code}» ведёт на страницу другой дороги. Маршрут ведёт куда " \
                      "заявлено — или это не маршрут."
    end
  end

  # ─── одна дорога ────────────────────────────────────────────────────────

  def test_a_road_answers_with_its_own_page
    road("GNR", "Великая северная")
    mid = road("MID", "Мидлендская")
    get path(:company, mid)
    assert_status 200
    assert_equal ["MID"], texts("h1"), "Страница не про ту дорогу, о которой спросили."
    assert_includes page.text, "Мидлендская"
  end

  def test_a_missing_road_is_404
    road("MID")
    get "/companies/999999"
    assert_status 404,
                  "Дороги нет, а ответ не 404. Пустая страница с 200 — неправда, которую " \
                  "никто не заметит; перенаправление на список — тоже неправда: спросили не " \
                  "о списке."
  end

  def test_a_road_links_back_to_the_registry
    mid = road("MID")
    get path(:company, mid)
    assert_includes hrefs, path(:companies),
                    "Со страницы дороги нет пути обратно в реестр."
  end

  private

  # Адреса дорог на странице — в порядке появления, каждый один раз.
  def linked_roads
    known = Company.all.to_h { |item| [path(:company, item), true] }
    hrefs.select { |path| known[path] }.uniq
  end
end
