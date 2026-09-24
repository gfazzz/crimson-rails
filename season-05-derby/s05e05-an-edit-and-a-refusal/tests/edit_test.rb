# CRIMSON RAILS — s05e05, проверка.
#
# Правка и снятие с реестра проверяются так же, как бланк: форма берётся со
# страницы и отправляется так, как её отправит браузер. Удаление — не
# исключение: кнопка «убрать» — тоже форма, и проверяется то, что случится,
# если её нажать.

require_relative "../../support/check.rb"

class EditTest < Crimson::Test
  def setup
    wipe!
    @mid = road("MID", "Мидлендская")
    @cal = road("CAL", "Каледонская")
  end

  def removal_form
    page.css("main form").find { |form| form.at_css("input[name='_method'][value='delete']") } ||
      flunk("На странице дороги нет кнопки, которая убирает её из реестра. Удаление — форма " \
            "с глаголом DELETE, а не ссылка: ссылка — это GET.")
  end

  def edit_form
    get path(:edit_company, @mid)
    assert_status 200, "Страница правки не открылась."
    form_on_page
  end

  # ─── маршруты ───────────────────────────────────────────────────────────

  def test_edit_update_and_destroy_are_routed
    assert_equal "companies#edit", route(:get, "/companies/MID/edit"),
                 "Правки нет: GET /companies/MID/edit никуда не ведёт."
    assert_equal "companies#update", route(:patch, "/companies/MID")
    assert_equal "companies#destroy", route(:delete, "/companies/MID")
  end

  def test_roads_are_still_not_created_here
    assert_nil route(:post, "/companies"),
               "Окно заводит дороги. В члены Палаты их принимает Палата, а не контора в " \
               "Дерби: этого обещания окно дать не может."
  end

  # ─── правка ─────────────────────────────────────────────────────────────

  def test_the_edit_form_goes_to_the_roads_address_with_patch
    form = edit_form
    assert_equal path(:company, @mid), URI(form["action"].to_s).path,
                 "Форма правки отправляется не на адрес дороги."
    assert_equal "patch", form_fields(form)["_method"],
                 "Форма правки шлёт не PATCH. Существующую запись правят по её адресу."
  end

  def test_the_edit_form_holds_what_is_there_now
    edit_form
    assert_equal "Мидлендская", form_fields["company[name]"],
                 "Форма правки пустая. Править — значит начинать с того, что есть."
  end

  def test_a_changed_name_is_303_to_the_road
    edit_form
    submit({ name: "Мидлендская дорога" }, scope: :company)
    assert_status 303
    assert_equal path(:company, @mid), URI(location).path
    assert_equal "Мидлендская дорога", @mid.reload.name
    follow!
    assert_includes page.css("[role='status']").text, "MID",
                    "После правки не сказано, что изменения внесены."
  end

  def test_a_blank_name_is_422_with_the_models_words
    edit_form
    submit({ name: "" }, scope: :company)
    assert_status 422, "Пустое название принято или отвергнуто не тем кодом."
    assert_equal "Мидлендская", @mid.reload.name
    probe = Company.new(code: "MID", name: "")
    probe.validate
    assert_includes page.css("[role='alert']").text, probe.errors.full_messages_for(:name).first,
                    "Причина отказа не названа словами модели."
    assert_equal path(:company, @mid), URI(form_on_page["action"].to_s).path,
                 "Вернувшаяся форма правки ведёт не на адрес дороги."
  end

  def test_the_code_is_not_edited_through_the_form
    edit_form
    submit({ name: "Мидлендская" }, scope: :company, inject: { "company[code]" => "MXD" })
    assert_equal "MID", @mid.reload.code,
                 "Код дороги поменяли, дописав поле в запрос. Код — адрес дороги: ключ, " \
                 "который меняют, ломает все ссылки на неё сразу."
    get path(:company, @mid)
    assert_status 200
  end

  def test_a_patch_without_the_road_is_400
    patch path(:company, @mid), params: { name: "x" }
    assert_status 400
  end

  def test_an_unknown_road_has_no_edit
    get "/companies/ZZZ/edit"
    assert_status 404
  end

  # ─── снятие с реестра ───────────────────────────────────────────────────

  def test_a_road_with_nothing_attached_is_removed_with_303
    get path(:company, @cal)
    submit(form: removal_form)
    assert_status 303,
                  "Снятие с реестра ответило не 303. На DELETE, перенаправленный кодом 302, " \
                  "браузер вправе повторить DELETE по новому адресу."
    assert_equal path(:companies), URI(location).path
    refute Company.exists?(@cal.id), "Дорога осталась в реестре."
    follow!
    assert_includes page.css("[role='status']").text, "CAL"
  end

  def test_a_road_with_settlements_is_refused_422_on_its_own_page
    Settlement.create!(company: @mid, period: "1891-09", pence: 192_240)
    get path(:company, @mid)
    submit(form: removal_form)
    assert_status 422,
                  "Отказ снять дорогу с реестра ответил не 422. 303 — «сделано, смотри там», " \
                  "а сделано ничего не было."
    assert Company.exists?(@mid.id)
    assert_equal ["MID"], texts("h1"), "После отказа окно показало не страницу этой дороги."
    probe = Company.find(@mid.id)
    probe.destroy
    assert_includes page.css("[role='alert']").text, probe.errors.full_messages.first,
                    "Причина отказа не названа: у дороги расчёты, и это деньги, которые ей должны."
  end

  def test_a_road_with_consignments_is_refused_too
    shipment(@mid, "B-0992")
    delete path(:company, @mid)
    assert_status 422
    assert Company.exists?(@mid.id)
    assert_match(/перевозк/, page.css("[role='alert']").text)
  end

  def test_an_unknown_road_cannot_be_removed
    delete "/companies/ZZZ"
    assert_status 404
  end

  def test_a_get_never_removes
    get "/companies/CAL?_method=delete"
    assert Company.exists?(@cal.id),
           "Запрос GET убрал дорогу. GET обещает ничего не менять: его повторяют, " \
           "запрашивают заранее и присылают по ссылке."
  end
end
