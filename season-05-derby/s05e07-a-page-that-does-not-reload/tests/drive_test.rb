# CRIMSON RAILS — s05e07, проверка в браузере.
#
# Turbo Drive: переходы и формы без перезагрузки. Перед каждым действием на
# окне ставится метка; перезагрузка её стирает, Turbo — нет. Поэтому здесь
# проверяется не «страница открылась», а что она открылась **не
# перезагружаясь**, — и то, что Turbo без перезагрузки обязан сохранить или,
# наоборот, не показать второй раз.
#
# Нужен Chrome: make test-visual.

require_relative "../../support/browser.rb"

class DriveTest < Crimson::BrowserTest
  def setup
    super
    wipe!
    @mid = road("MID", "Мидлендская")
    @cal = road("CAL", "Каледонская")
    Settlement.create!(company: @mid, period: "1891-09", pence: 192_240)
  end

  # ─── переходы ───────────────────────────────────────────────────────────

  def test_a_link_changes_the_page_not_the_window
    visit path(:companies)
    mark_window!
    browser.click_link "MID"
    assert_selector "h1", text: "MID"
    assert_not_reloaded "Переход по ссылке на страницу MID"
    assert_equal path(:company, @mid), browser.current_path, "Адрес в окне не сменился."
  end

  def test_back_returns_without_reloading
    visit path(:companies)
    mark_window!
    browser.click_link "MID"
    assert_selector "h1", text: "MID"
    browser.go_back
    assert_selector "h1", text: "Реестр дорог"
    assert_not_reloaded "Возврат назад"
  end

  def test_the_window_title_follows_the_page
    visit path(:companies)
    browser.click_link "MID"
    assert_selector "h1", text: "MID"
    assert_includes browser.title, "MID",
                    "Заголовок окна остался от прошлой страницы. Turbo меняет и `<title>`, если " \
                    "страница его объявляет."
  end

  # ─── формы ──────────────────────────────────────────────────────────────

  def test_a_refused_form_shows_its_reasons_in_place
    visit path(:new_consignment)
    mark_window!
    browser.click_button "Внести бланк"
    assert_selector "[role='alert']", text: "Номер бланка"
    assert_not_reloaded "Непринятая форма бланка"
    assert_selector "h1", text: "Новый бланк"
  end

  def test_an_accepted_form_goes_on_and_tells
    visit path(:new_consignment, company: "MID")
    mark_window!
    fill_bill("B-0992")
    assert_selector "[role='status']", text: "B-0992"
    assert_selector "h1", text: "MID"
    assert_not_reloaded "Принятая форма бланка"
  end

  def test_the_notice_does_not_come_back_from_the_cache
    visit path(:new_consignment, company: "MID")
    fill_bill("B-0992")
    assert_selector "[role='status']", text: "B-0992"
    browser.click_link "Реестр дорог"
    assert_selector "h1", text: "Реестр дорог"
    browser.go_back
    assert_selector "h1", text: "MID"
    assert browser.has_no_selector?("[role='status']", text: "B-0992", wait: 1),
           "«Назад» снова сказало «Бланк B-0992 внесён». Уходя со страницы, Turbo кладёт её " \
           "снимок в кеш; сообщение, попавшее в снимок, вернётся с ним — о бланке, внесённом " \
           "давно."
  end

  # ─── черновик ───────────────────────────────────────────────────────────

  def test_the_draft_survives_a_link
    visit path(:companies)
    mark_window!
    draft_field!
    browser.fill_in "Черновик телеграммы", with: "ЛОНДОН СЕКРЕТАРИАТУ"
    browser.click_link "MID"
    assert_selector "h1", text: "MID"
    assert_not_reloaded "Переход с черновиком"
    assert_equal "ЛОНДОН СЕКРЕТАРИАТУ", browser.find_field("Черновик телеграммы").value,
                 "Черновик пропал при переходе. Turbo заменил тело страницы целиком — вместе " \
                 "с тем, что Эшворт успела набрать."
  end

  def test_the_draft_survives_a_form
    visit path(:new_consignment, company: "MID")
    draft_field!
    browser.fill_in "Черновик телеграммы", with: "ДЕРБИ ОТВЕТ"
    fill_bill("B-0993")
    assert_selector "[role='status']", text: "B-0993"
    assert_equal "ДЕРБИ ОТВЕТ", browser.find_field("Черновик телеграммы").value,
                 "Черновик пропал после отправки формы."
  end

  # ─── снятие с реестра ───────────────────────────────────────────────────

  def test_removal_asks_first_and_a_no_keeps_the_road
    visit path(:company, @cal)
    browser.dismiss_confirm { browser.click_button "Убрать из реестра" }
    assert_selector "h1", text: "CAL"
    assert Company.exists?(@cal.id),
           "Дорогу убрали, хотя на вопрос ответили «нет». Кнопка «убрать» стоит рядом с " \
           "«править», и подтверждение — не формальность."
  end

  def test_a_yes_removes_without_reloading
    visit path(:company, @cal)
    mark_window!
    browser.accept_confirm { browser.click_button "Убрать из реестра" }
    assert_selector "h1", text: "Реестр дорог"
    assert_selector "[role='status']", text: "CAL"
    assert_not_reloaded "Снятие дороги с реестра"
    refute Company.exists?(@cal.id)
  end

  def test_a_refused_removal_stays_in_place_with_the_reason
    visit path(:company, @mid)
    mark_window!
    browser.accept_confirm { browser.click_button "Убрать из реестра" }
    assert_selector "[role='alert']", text: "Нельзя убрать"
    assert_selector "h1", text: "MID"
    assert_not_reloaded "Отказ снять дорогу с реестра"
    assert Company.exists?(@mid.id)
  end

  private

  def draft_field!
    assert browser.has_field?("Черновик телеграммы", wait: 1),
           "В шапке нет поля с подписью «Черновик телеграммы». Подпись — то, по чему поле " \
           "находят и глазами, и вслух."
  end

  def fill_bill(reference)
    browser.fill_in "Номер бланка", with: reference
    browser.fill_in "Описание груза", with: "чай, ящиков 12"
    browser.fill_in "Дата отправки", with: "1891-10-19"
    browser.fill_in "Плата, пенсов", with: "960"
    browser.fill_in "Вес, фунтов", with: "336"
    browser.click_button "Внести бланк"
  end
end
