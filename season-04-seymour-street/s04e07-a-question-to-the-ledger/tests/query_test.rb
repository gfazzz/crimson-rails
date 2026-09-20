# CRIMSON RAILS — s04e07, проверка.
#
# Здесь проверяется не результат, а цена: сколько запросов уходит в базу.
# Результат у N+1 правильный — этим он и опасен. На десяти строках он быстрый,
# на восьми тысячах он и есть причина, по которой отчёт считается полчаса.

require_relative "../../support/check.rb"

class QueryTest < Crimson::Test
  def setup
    wipe!("legs", "consignments", "companies")
    @gnr = Company.create!(code: "GNR", name: "Великая северная")
    @ner = Company.create!(code: "NER", name: "Северо-восточная")
    @mdl = Company.create!(code: "MDL", name: "Мидлендская дорога")
  end

  # Смена: n перевозок, у каждой два участка — по GNR и по одной из двух
  # других дорог.
  def shift(count, settled: false, on: "1891-08-19", mark: "B")
    Array.new(count) do |i|
      record = Consignment.create!(**bill(company_id: @gnr.id, reference: "#{mark}-#{i}",
                                          sent_on: on, settled: settled))
      Leg.create!(consignment: record, company: @gnr, position: 1, miles: 12)
      Leg.create!(consignment: record, company: i.even? ? @ner : @mdl, position: 2, miles: 190)
      record
    end
  end

  # ─── отбор — это кусок запроса ──────────────────────────────────────────

  def test_a_scope_asks_nothing_until_asked
    shift(2)
    asked = queries("consignments") { Consignment.unsettled }
    assert_empty asked,
                 "Отбор сходил в базу до того, как у него спросили. Отбор — не запрос, а его " \
                 "кусок: пока никто не просит строк, спрашивать не у кого."
  end

  def test_scopes_add_up_into_one_question
    shift(2, on: "1891-08-19")
    shift(1, on: "1891-07-01", mark: "J")
    asked = queries("consignments") do
      Consignment.unsettled.sent_between("1891-08-01", "1891-08-31").to_a
    end
    assert_equal 1, asked.length,
                 "Два отбора должны сложиться в один запрос. Если их два — где-то посередине " \
                 "кто-то попросил строки: `to_a`, `each`, `map` или `count`."
  end

  def test_unsettled_selects_what_it_says
    shift(2, settled: false)
    Consignment.create!(**bill(company_id: @gnr.id, reference: "B-DONE", settled: true))
    assert_equal %w[B-0 B-1], Consignment.unsettled.order(:reference).pluck(:reference)
  end

  def test_sent_between_takes_both_ends
    shift(1, on: "1891-08-01")
    Consignment.create!(**bill(company_id: @gnr.id, reference: "B-END", sent_on: "1891-08-31"))
    Consignment.create!(**bill(company_id: @gnr.id, reference: "B-LATE", sent_on: "1891-09-01"))
    found = Consignment.sent_between("1891-08-01", "1891-08-31")
    assert_equal 2, found.count,
                 "Границы включаются: отправленное 1 и 31 августа входит в август."
  end

  def test_through_company_finds_consignments_by_the_roads_that_carried_them
    shift(4)
    found = Consignment.through_company("MDL").order(:reference).pluck(:reference)
    assert_equal %w[B-1 B-3], found,
                 "Отбор по дороге пути — это отбор по участкам, а не по отправителю."
  end

  def test_through_company_stays_one_question
    shift(4)
    asked = queries { Consignment.through_company("MDL").to_a }
    assert_equal 1, asked.length,
                 "Отбор по дороге должен уходить одним запросом. Если их два — отбор участков " \
                 "загрузили заранее и подставили список номеров: на сорока тысячах перевозок " \
                 "это `IN (…)` на сорок тысяч чисел, который иные базы просто не примут."
  end

  def test_legs_by_road_do_not_drag_the_register_along
    shift(2)
    found = Leg.through_company("MDL").first
    refute found.association(:company).loaded?,
           "Реестр загружен вместе с участками. Здесь он нужен для отбора, а не для чтения: " \
           "`joins` подшивает таблицу к запросу и объектов не создаёт, `includes` создаёт."
  end

  # ─── цена обхода ────────────────────────────────────────────────────────

  def test_route_sheet_is_right
    shift(2)
    sheet = Consignment.route_sheet(Consignment.order(:reference))
    assert_equal %w[B-0 B-1], sheet.map { |row| row[:reference] }
    assert_equal %w[GNR NER], sheet.first[:roads]
  end

  def test_route_sheet_does_not_grow_with_the_number_of_rows
    shift(3)
    small = queries("legs") { Consignment.route_sheet(Consignment.all) }
    wipe!("legs", "consignments")
    shift(12)
    large = queries("legs") { Consignment.route_sheet(Consignment.all) }

    assert_equal small.length, large.length,
                 "Запросов к участкам стало больше от того, что строк стало больше. Это N+1: " \
                 "на трёх перевозках он незаметен, на восьми тысячах отчёт считается полчаса."
    assert_operator large.length, :<=, 2,
                    "Участки должны быть забраны одним запросом на весь отбор."
  end

  def test_route_sheet_does_not_ask_the_register_row_by_row
    shift(12)
    asked = queries("companies") { Consignment.route_sheet(Consignment.all) }
    assert_operator asked.length, :<=, 2,
                    "Реестр спрашивают по одному разу на участок. Цепочку связей забирают " \
                    "целиком: `includes(legs: :company)`."
  end

  def test_miles_by_company_is_counted_by_the_base
    shift(4)
    asked = queries("legs") do
      @sum = Consignment.miles_by_company(Consignment.all)
    end
    assert_equal 1, asked.length,
                 "Свод по дорогам должен уходить одним запросом: считает база, а не Ruby. " \
                 "Свод, собранный объектами, — это восемь тысяч объектов, которые потом выбросят."
    assert_equal 48, @sum[@gnr.id], "Четыре участка по двенадцать миль."
    assert_equal 380, @sum[@ner.id]
    assert_equal 380, @sum[@mdl.id]
  end

  def test_miles_by_company_respects_the_selection
    shift(4)
    sum = Consignment.miles_by_company(Consignment.through_company("MDL"))
    assert_equal 380, sum[@mdl.id]
    assert_equal 24, sum[@gnr.id], "Только по отобранным перевозкам, а не по всей ведомости."
    assert_nil sum[@ner.id]
  end

  # ─── как спрашивают дёшево ──────────────────────────────────────────────

  def test_pluck_brings_values_not_objects
    shift(3)
    asked = queries("consignments") do
      @codes = Consignment.order(:reference).pluck(:reference)
    end
    assert_equal 1, asked.length
    assert_equal %w[B-0 B-1 B-2], @codes
    assert_match(/SELECT "consignments"\."reference"/, asked.first,
                 "`pluck` должен просить только нужный столбец: объекты здесь никому не нужны.")
  end

  def test_exists_does_not_count_the_whole_ledger
    shift(5)
    asked = queries("consignments") { Consignment.unsettled.exists? }
    assert_equal 1, asked.length
    assert_match(/LIMIT/i, asked.first,
                 "`exists?` спрашивает «есть ли хоть одна» и останавливается на первой. " \
                 "`count.positive?` считает все, `any?` на загруженном отборе — тоже.")
  end

  # ─── прежнее цело ───────────────────────────────────────────────────────

  def test_associations_still_work
    record = shift(1).first
    assert_equal %w[GNR NER], record.reload.companies.order(:code).pluck(:code)
    assert_equal [1, 2], record.legs.map(&:position)
  end

  def test_schema_did_not_change
    assert_equal migration_versions.max, schema_version
    assert_equal %w[companies consignments legs], tables
  end
end
