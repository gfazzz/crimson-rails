# CRIMSON RAILS — s05e08, проверка.
#
# Фрейм — кусок страницы со своим адресом. Проверяется протокол, по которому
# Turbo его подгружает и меняет: запрос с заголовком `Turbo-Frame` и в ответе
# — фрейм с тем же id. Не нашёл — «Content missing» вместо содержимого. Всё
# это видно без браузера: и что страница дороги расчётов больше не считает, и
# что лист расчётов отвечает за себя сам, и что правка встаёт на место
# карточки.

require_relative "../../support/check.rb"

class FrameTest < Crimson::Test
  include ActionView::RecordIdentifier

  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    Settlement.create!(company: @mid, period: "1891-08", pence: 192_240)
    Settlement.create!(company: @mid, period: "1891-09", pence: 192_240)
  end

  def settlements_id = dom_id(@mid, :settlements)
  def card_id = dom_id(@mid, :card)

  # ─── лист расчётов — со своим адресом ───────────────────────────────────

  def test_the_settlements_sheet_is_routed
    assert_equal "settlements#index", route(:get, "/companies/MID/settlements"),
                 "У листа расчётов нет своего адреса: GET /companies/MID/settlements никуда не ведёт."
  end

  def test_the_road_page_no_longer_counts_the_settlements
    get path(:company, @mid)
    assert_status 200
    raw = raw_page
    assert_nil raw.at_css("main table"),
               "Страница дороги сама отрисовывает таблицу расчётов. Лист расчётов вклеивается " \
               "фреймом со своим адресом: страница дороги его не считает и не ждёт."
    frame = raw.at_css("turbo-frame[src]")
    refute_nil frame, "На странице дороги нет фрейма, который подгружает лист расчётов."
    assert_equal path(:company_settlements, @mid), URI(frame["src"]).path,
                 "Фрейм подгружает не лист расчётов этой дороги."
  end

  def test_the_sheet_answers_a_frame_request_with_that_frame
    get path(:company, @mid)
    frame = raw_page.at_css("turbo-frame[src]")
    refute_nil frame
    frame(frame["src"], frame["id"])
    assert_status 200
    answered = raw_page.at_css("turbo-frame[id='#{frame['id']}']")
    refute_nil answered,
               "Лист расчётов отвечает на запрос фрейма «#{frame['id']}» без фрейма с тем же id. " \
               "Turbo напишет на его месте «Content missing»."
    assert_equal 2, answered.css("tbody tr").size, "Во фрейме не таблица расчётов этой дороги."
  end

  def test_the_sheet_is_also_a_page_of_its_own
    get path(:company_settlements, @mid)
    assert_status 200
    assert_equal 1, raw_page.css("main h1").size,
                 "Лист расчётов, открытый сам по себе, — не страница. Фрейм без Turbo — это " \
                 "ссылка на его адрес, и по ней обязан открыться полный лист."
    refute_nil raw_page.at_css("nav"), "У листа расчётов нет макета: на нём нет пути в реестр."
  end

  def test_the_sheet_of_an_unknown_road_is_404
    get "/companies/ZZZ/settlements"
    assert_status 404
  end

  def test_the_reader_still_sees_the_table_on_the_road_page
    get path(:company, @mid)
    table = page.css("main table").find { |node| node.at_css("caption")&.text.to_s.include?("Расчёт") }
    refute_nil table,
               "После подгрузки фрейма на странице дороги нет таблицы расчётов. Читающий " \
               "видит страницу такой, какой её собрал Turbo."
  end

  # ─── карточка и правка на её месте ──────────────────────────────────────

  def test_edit_opened_from_the_card_answers_with_the_card
    get path(:company, @mid)
    card = raw_page.at_css("turbo-frame[id='#{card_id}']")
    refute_nil card, "У дороги нет карточки-фрейма, в которой открывается правка."
    edit = card.css("a[href]").find { |node| URI(node["href"]).path == path(:edit_company, @mid) }
    refute_nil edit, "Ссылка «Править» — не внутри карточки: правка откроется на всю страницу."

    frame(path(:edit_company, @mid), card_id)
    assert_status 200
    answered = raw_page.at_css("turbo-frame[id='#{card_id}']")
    refute_nil answered,
               "Страница правки на запрос фрейма карточки отвечает без карточки. Turbo напишет " \
               "«Content missing» на месте названия дороги."
    refute_nil answered.at_css("form"), "В карточке, пришедшей со страницы правки, нет формы."
  end

  def test_an_accepted_edit_comes_back_into_the_card
    frame(path(:edit_company, @mid), card_id)
    form = card_form
    submit({ name: "Мидлендская дорога" }, scope: :company, form: form, headers: { "Turbo-Frame" => card_id })
    assert_status 303
    frame(URI(location).path, card_id)
    assert_status 200
    answered = raw_page.at_css("turbo-frame[id='#{card_id}']")
    refute_nil answered,
               "После правки Turbo идёт по перенаправлению за тем же фреймом — а на странице " \
               "дороги его нет."
    assert_includes answered.text, "Мидлендская дорога", "В карточке — не новое название."
  end

  def test_a_refused_edit_stays_in_the_card_with_its_reasons
    frame(path(:edit_company, @mid), card_id)
    form = card_form
    submit({ name: "" }, scope: :company, form: form, headers: { "Turbo-Frame" => card_id })
    assert_status 422
    answered = raw_page.at_css("turbo-frame[id='#{card_id}']")
    refute_nil answered,
               "Непринятая правка ответила без карточки. Turbo возьмёт из ответа 422 тот же " \
               "фрейм — и не найдёт его."
    refute_nil answered.at_css("[role='alert']"), "В вернувшейся карточке нет причин отказа."
  end

  def test_the_edit_page_still_stands_on_its_own
    get path(:edit_company, @mid)
    assert_status 200
    assert_equal 1, raw_page.css("main h1").size
    refute_nil raw_page.at_css("main form")
  end

  def card_form
    raw_page.at_css("turbo-frame[id='#{card_id}'] form") ||
      flunk("Страница правки на запрос фрейма карточки не отдала карточку с формой.")
  end

  # ─── обещание каждого фрейма ────────────────────────────────────────────

  def test_no_link_in_a_frame_leads_to_content_missing
    [path(:company, @mid), path(:edit_company, @mid), path(:company_settlements, @mid)].each do |address|
      get address
      assert_empty broken_frame_links(raw_page),
                   "На странице #{address} есть ссылка внутри фрейма, которая ведёт туда, где " \
                   "этого фрейма нет. Turbo откроет её в том же фрейме и напишет «Content " \
                   "missing». Такая ссылка обязана уводить всю страницу: " \
                   "`data-turbo-frame=\"_top\"`."
    end
  end
end
