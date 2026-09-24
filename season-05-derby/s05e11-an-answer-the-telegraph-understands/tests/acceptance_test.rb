# CRIMSON RAILS — s05e11, приёмка сезона 5.
#
# Не список, а обход. На засеянном реестре берётся каждый маршрут, который
# окно объявило, и спрашивается то, что сезон обещал с первой серии: адрес
# ведёт куда заявлено и отвечает; где нечего показать — 404; страница
# читается; фрейм держит обещание; форма уходит туда, где её примут.
#
# Маршрут, добавленный после этой серии, попадёт в обход сам: проверка не
# знает списка адресов наизусть, она читает таблицу маршрутов.

require_relative "../../support/check.rb"

class AcceptanceTest < Crimson::Test
  KNOWN = { code: "MID", company_code: "MID", reference: "B-0992", settlement_period: "1891-09" }.freeze
  MISSING = { code: "ZZZ", company_code: "ZZZ", reference: "B-9999", settlement_period: "1861-01" }.freeze

  def setup
    wipe!
    mid = road("MID", "Мидлендская")
    ner = road("NER", "Северо-восточная")
    road("MDL", "Мидлендская (Лондон)")
    bill = shipment(mid, "B-0992")
    Leg.create!(consignment: bill, company: mid, position: 1, role: :collected, miles: 12)
    Leg.create!(consignment: bill, company: ner, position: 2, role: :delivered, miles: 108)
    Settlement.create!(company: mid, period: "1891-09", pence: 192_240)
    Settlement.create!(company: mid, period: "1891-08", pence: 190_560, state: :paid)
  end

  # Все страницы окна: маршруты GET, свои, с подставленными ключами.
  def pages(values = KNOWN)
    own_routes.select { |item| item.verb == "GET" }.filter_map do |item|
      names = item.required_parts
      next unless names.all? { |name| values.key?(name) }

      [item.defaults.values_at(:controller, :action).join("#"), item.format(values.slice(*names)), names]
    end.uniq { |_, address, _| address }
  end

  def own_routes
    Rails.application.routes.routes.select do |item|
      controller = item.defaults[:controller]
      controller && !controller.start_with?("rails/", "action_", "active_", "turbo/")
    end
  end

  # ─── каждый адрес ───────────────────────────────────────────────────────

  def test_every_route_has_someone_to_answer
    own_routes.each do |item|
      controller, action = item.defaults.values_at(:controller, :action)
      klass = "#{controller.camelize}Controller".safe_constantize
      assert klass&.action_methods&.include?(action),
             "#{item.verb} #{item.path.spec} обещает #{controller}##{action}, а ответить некому."
    end
  end

  def test_every_page_answers_200_as_a_page
    list = pages
    assert_operator list.size, :>=, 7, "Страниц в обходе подозрительно мало: #{list.map(&:second).join(', ')}."
    list.each do |target, address, _|
      get address
      assert_status 200, "#{address} (#{target}) не открылся на реестре, где всё для него есть."
      assert_equal "text/html", media_type, "#{address} ответил не страницей."
    end
  end

  def test_where_there_is_nothing_to_show_it_is_404
    pages.each do |target, _, names|
      next if names.empty?

      names.each do |name|
        values = KNOWN.merge(name => MISSING[name])
        address = own_routes.find { |item| item.defaults.values_at(:controller, :action).join("#") == target && item.verb == "GET" }
                            .format(values.slice(*names))
        get address
        assert_status 404, "#{address}: #{name} указывает в никуда — а ответ не 404."
      end
    end
  end

  def test_every_page_reads_aloud
    pages.each do |_, address, _|
      get address
      doc = page
      assert_match(/\Aru/, doc.at_css("html")&.[]("lang").to_s, "#{address}: язык страницы не объявлен.")
      assert_equal 1, doc.css("h1").size, "#{address}: главный заголовок не один."
      assert_equal 1, doc.css("main").size, "#{address}: нет одной главной части."
      assert doc.at_css("nav a[href='#{path(:companies)}']"), "#{address}: из навигации не попасть в реестр."
    end
  end

  def test_no_frame_link_anywhere_leads_to_content_missing
    pages.each do |_, address, _|
      get address
      broken = broken_frame_links(raw_page)
      assert_empty broken, "#{address}: ссылки во фреймах ведут в «Content missing»: #{broken.join('; ')}."
    end
  end

  def test_every_form_anywhere_goes_where_it_is_received
    pages.each do |_, address, _|
      get address
      page.css("form").each do |form|
        fields = form_fields(form)
        verb = (fields["_method"] || form["method"] || "get").downcase.to_sym
        action = URI(form["action"].to_s).path
        refute_nil route(verb, action),
                   "#{address}: форма уходит #{verb.upcase} #{action} — а там её никто не принимает."
      end
    end
  end

  def test_nothing_is_changed_by_looking
    counts = -> { [Company.count, Consignment.count, Leg.count, Settlement.where(state: :paid).count] }
    before = counts.call
    pages.each { |_, address, _| get address }
    assert_equal before, counts.call,
                 "Обход страниц запросами GET изменил реестр. GET ничего не меняет — никогда."
  end
end
