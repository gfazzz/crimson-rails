# CRIMSON RAILS — s05e10, проверка в браузере.
#
# Stimulus — ровно там, где Turbo мало: сумма фунтами, шиллингами и пенсами,
# пока кассир набирает пенсы. Проверяется то, что видно только в окне: чтение
# меняется на каждую клавишу, не спрашивая сервера; работает после визита
# Turbo, а не только при первой загрузке; и говорит то же, что сервер, — на
# любом числе.
#
# Нужен Chrome: make test-visual.

require_relative "../../support/browser.rb"

class MoneyTest < Crimson::BrowserTest
  def setup
    super
    wipe!
    @mid = road("MID", "Мидлендская")
  end

  def open_form(via_turbo: false)
    if via_turbo
      visit path(:company, @mid)
      mark_window!
      browser.click_link "Внести бланк этой дороги"
      assert_selector "h1", text: "Новый бланк"
    else
      visit path(:new_consignment, company: "MID")
    end
    assert browser.has_field?("Плата, пенсов", wait: 1), "На бланке нет поля «Плата, пенсов»."
  end

  def reading
    field = browser.find_field("Плата, пенсов")
    id = field[:"aria-describedby"].to_s.split.first
    flunk "Поле платы ничем не описано: у него нет `aria-describedby`, и чтение суммы " \
          "не связано с полем ни для глаз, ни для слуха." if id.to_s.empty?
    browser.find(:css, "##{id}", visible: :all)
  end

  def type_pence(text)
    field = browser.find_field("Плата, пенсов")
    field.set("")
    field.send_keys(text)
  end

  # ─── чтение на каждую клавишу ───────────────────────────────────────────

  def test_the_reading_follows_the_typing
    open_form
    type_pence("775")
    assert browser.has_css?("##{reading[:id]}", text: "£3 4s 7d", wait: 2),
           "Набрали 775 пенсов, а рядом не «£3 4s 7d». Чтение обязано появляться, пока " \
           "набирают, — без отправки формы."
  end

  def test_every_keystroke_is_read
    open_form
    field = browser.find_field("Плата, пенсов")
    field.set("")
    { "2" => "£0 0s 2d", "4" => "£0 2s 0d", "0" => "£1 0s 0d" }.each do |key, expected|
      field.send_keys(key)
      assert browser.has_css?("##{reading[:id]}", text: expected, wait: 2),
             "После «#{field.value}» чтение не «#{expected}», а «#{reading.text}». Чтение " \
             "меняется на каждую клавишу."
    end
  end

  def test_typing_asks_the_server_nothing
    open_form
    before = browser.evaluate_script("performance.getEntriesByType('resource').length")
    type_pence("192240")
    assert browser.has_css?("##{reading[:id]}", text: "£801 0s 0d", wait: 2)
    after = browser.evaluate_script("performance.getEntriesByType('resource').length")
    assert_equal before, after,
                 "Пока набирали сумму, окно спрашивало сервер #{after - before} раз. Чтение " \
                 "суммы не требует ничего, кроме числа в поле: у стола, никуда не запрашивая."
  end

  def test_nonsense_is_not_read_as_money
    open_form
    type_pence("-5")
    text = reading.text
    refute_match(/NaN|£-|undefined/, text,
                 "На «-5» чтение показывает «#{text}». Неверная сумма — не сумма.")
  end

  # ─── после визита Turbo ─────────────────────────────────────────────────

  def test_it_works_after_a_turbo_visit_too
    open_form(via_turbo: true)
    assert_not_reloaded "Переход к бланку со страницы дороги"
    type_pence("775")
    assert browser.has_css?("##{reading[:id]}", text: "£3 4s 7d", wait: 2),
           "Бланк открыт переходом Turbo — и чтение не работает. Код, который ждёт " \
           "`DOMContentLoaded`, выполнился один раз, на первой странице; для Turbo страница " \
           "не загружается, а подменяется. Stimulus подключает поведение каждый раз, когда " \
           "элемент появился."
  end

  def test_a_refused_form_comes_back_already_read
    open_form
    type_pence("775")
    browser.click_button "Внести бланк"
    assert_selector "[role='alert']", text: "Номер бланка"
    assert browser.has_css?("##{reading[:id]}", text: "£3 4s 7d", wait: 2),
           "Бланк вернулся с отказом и с вписанными 775 пенсами — а чтения рядом нет, пока " \
           "не нажмёшь клавишу. Поведение обязано подключаться к тому, что уже есть в поле."
  end

  # ─── говорит то же, что сервер ──────────────────────────────────────────

  def test_the_reading_agrees_with_the_server
    open_form
    helper = Object.new.extend(ApplicationHelper)
    [1, 11, 12, 239, 240, 241, 2_879, 192_251].each do |pence|
      type_pence(pence.to_s)
      expected = helper.money(pence)
      assert browser.has_css?("##{reading[:id]}", text: expected, exact_text: true, wait: 2),
             "На #{pence} пенсов окно читает «#{reading.text}», а сервер — «#{expected}». " \
             "Правило чтения повторено в двух местах; оба обязаны говорить одно."
    end
  end

  def test_the_reading_is_heard_from_the_field
    open_form
    node = reading
    live = node.tag_name == "output" || %w[polite assertive].include?(node[:"aria-live"]) ||
           %w[status].include?(node[:role])
    assert live,
           "Чтение суммы — не живая область: глазами видно, вслух — тишина. `<output>` или " \
           "`aria-live` скажут «£3 4s 7d», не уводя из поля."
  end

  # ─── правда — у сервера ─────────────────────────────────────────────────

  def test_the_server_still_decides
    open_form
    browser.fill_in "Номер бланка", with: "B-0992"
    browser.fill_in "Описание груза", with: "чай"
    browser.fill_in "Дата отправки", with: "1891-10-27"
    browser.fill_in "Вес, фунтов", with: "10"
    browser.execute_script(<<~JS)
      const field = document.querySelector("[name='consignment[pence]']")
      field.removeAttribute("min"); field.value = "0"
      field.dispatchEvent(new Event("input", { bubbles: true }))
    JS
    browser.click_button "Внести бланк"
    assert_selector "[role='alert']", text: "Плата"
    assert_nil Consignment.find_by(reference: "B-0992"),
               "Бланк с платой 0 лёг в реестр. То, что делается у стола, ничего не решает: " \
               "проверяет сервер."
  end
end
