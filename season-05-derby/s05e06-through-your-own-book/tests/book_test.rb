# CRIMSON RAILS — s05e06, проверка.
#
# Вложенный адрес — обещание: перевозку ищут в книге её дороги. Поэтому
# главное свойство серии — отрицательное: бланк, который в реестре есть, через
# книгу чужой дороги не открывается. Не перенаправляется, не показывается с
# пометкой — 404: в этой книге его нет.

require_relative "../../support/check.rb"

class BookTest < Crimson::Test
  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    @mdl = road("MDL", "Мидлендская (Лондон)")
    @ner = road("NER", "Северо-восточная")
  end

  def leg(consignment, company, position, role, miles)
    Leg.create!(consignment: consignment, company: company, position: position, role: role, miles: miles)
  end

  # ─── маршруты ───────────────────────────────────────────────────────────

  def test_the_book_and_a_bill_in_it_are_routed
    assert_equal "consignments#index", route(:get, "/companies/MID/consignments"),
                 "Книги перевозок нет: GET /companies/MID/consignments никуда не ведёт."
    assert_equal "consignments#show", route(:get, "/companies/MID/consignments/B-0992")
    found = Rails.application.routes.recognize_path("/companies/MID/consignments/B-0992")
    assert_equal %w[MID B-0992], [found[:company_code], found[:reference]],
                 "Вложенный адрес несёт не то, что обещает: код дороги и номер бланка."
  end

  def test_a_bill_is_addressed_through_its_road
    bill = shipment(@mid, "B-0992")
    assert_equal "/companies/MID/consignments/B-0992", path(:company_consignment, @mid, bill),
                 "Адрес перевозки — не номер её бланка в книге её дороги."
  end

  def test_the_code_rule_holds_in_the_nested_address_too
    assert_nil route(:get, "/companies/mid/consignments"),
               "Во вложенном адресе код дороги не проверяется образцом. Образец один (s05e02) " \
               "— и для `:code`, и для `:company_code`."
  end

  # ─── книга ──────────────────────────────────────────────────────────────

  def test_the_book_holds_only_its_own_bills
    shipment(@mid, "B-0992")
    shipment(@mid, "B-0993")
    shipment(@mdl, "D-41207")
    get path(:company_consignments, @mid)
    assert_status 200
    assert_equal %w[B-0992 B-0993], bill_links,
                 "В книге MID — чужие бланки или не все свои. Листы одной дороги не подшивают в " \
                 "книгу другой."
  end

  def test_the_book_is_in_date_order
    shipment(@mid, "B-0003", sent_on: Date.new(1891, 10, 3))
    shipment(@mid, "B-0001", sent_on: Date.new(1891, 10, 1))
    shipment(@mid, "B-0002", sent_on: Date.new(1891, 10, 2))
    get path(:company_consignments, @mid)
    assert_equal %w[B-0001 B-0002 B-0003], bill_links, "Книга идёт не по дате отправки."
  end

  def test_an_empty_book_is_an_answer
    get path(:company_consignments, @ner)
    assert_status 200, "Пустая книга — тоже ответ, как пустой реестр (s05e01)."
  end

  def test_the_book_of_an_unknown_road_is_404
    get "/companies/ZZZ/consignments"
    assert_status 404
  end

  def test_the_road_page_leads_to_its_book
    get path(:company, @mid)
    assert_includes hrefs, path(:company_consignments, @mid), "Со страницы дороги нет пути в её книгу."
  end

  # ─── бланк через свою книгу ─────────────────────────────────────────────

  def test_a_bill_opens_through_its_own_book
    bill = shipment(@mid, "B-0992")
    get path(:company_consignment, @mid, bill)
    assert_status 200
    assert_includes texts("h1").join, "B-0992", "Страница перевозки не про тот бланк."
  end

  def test_a_bill_does_not_open_through_another_roads_book
    shipment(@mdl, "D-41207")
    get "/companies/MID/consignments/D-41207"
    assert_status 404,
                  "Бланк MDL открылся через книгу MID. Он есть в реестре — но не в этой книге. " \
                  "Перевозку ищут среди перевозок дороги (`@company.consignments`), а не во " \
                  "всём реестре; иначе через любую книгу видно всё."
  end

  def test_an_unknown_bill_in_a_real_book_is_404
    shipment(@mid, "B-0992")
    get "/companies/MID/consignments/B-9999"
    assert_status 404
  end

  # ─── участки ────────────────────────────────────────────────────────────

  def test_the_legs_are_listed_in_order_with_their_roads
    bill = shipment(@mid, "B-0992")
    # Три порядка расходятся: по номеру участка, по милям и по времени внесения.
    leg(bill, @ner, 2, :delivered, 12)
    leg(bill, @mid, 1, :collected, 108)
    get path(:company_consignment, @mid, bill)
    table = page.css("main table").find { |node| node.at_css("caption")&.text.to_s.include?("Участки") }
    refute_nil table, "Участков нет таблицей с подписью «Участки…»."
    rows = table.css("tbody tr").map { |row| row.css("th, td").map { |cell| cell.text.squish } }
    assert_equal [%w[1 MID принял 108], %w[2 NER сдал 12]], rows,
                 "Участки не по порядку, без дорог или роль названа не словом."
    road_links = table.css("a[href]").map { |node| URI(node["href"]).path }
    assert_equal [path(:company, @mid), path(:company, @ner)], road_links,
                 "Дорога участка не ведёт на страницу этой дороги."
  end

  def test_the_page_asks_the_base_the_same_number_of_times
    counts = [2, 6].map do |legs|
      wipe!
      mid = road("MID")
      bill = shipment(mid, "B-0992")
      legs.times { |index| leg(bill, road("R#{('A'.ord + index).chr}"), index + 1, index.zero? ? :collected : :hauled, 10) }
      queries("companies") { get path(:company_consignment, mid, bill) }.size
    end
    assert_equal counts.first, counts.last,
                 "Страница перевозки с шестью участками спрашивает дороги чаще, чем с двумя: " \
                 "#{counts.last} раз против #{counts.first}. Это N+1 из s04e07 — на странице."
  end

  private

  def bill_links
    hrefs.filter_map { |item| item[%r{\A/companies/[A-Z]+/consignments/([^/]+)\z}, 1] }.uniq
  end
end
