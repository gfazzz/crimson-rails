# Реестр дорог — первое, что конторе нужно без письма в Лондон.
#
# Одно действие — одно решение. Контроллер не считает и не проверяет: он
# находит, что просили, и отдаёт представлению.
class CompaniesController < ApplicationController
  # Найти дорогу — одно решение, и принимается оно в одном месте: теперь его
  # спрашивают четыре действия.
  before_action :set_company, only: %i[show edit update destroy]

  # Список. По коду: так дороги стоят в книгах Палаты, и так их ищут глазами.
  #
  # Пустой реестр — тоже ответ: 200 и пустой список, а не ошибка.
  #
  # Страницей — для человека, JSON — для телеграфного аппарата (s05e11).
  def index
    @companies = Company.order(:code)

    respond_to do |format|
      format.html
      format.json
    end
  end

  # Одна дорога. Расчёты на её странице — отдельным фреймом со своим адресом
  # (s05e08): страница их не считает и не ждёт.
  def show; end

  def edit; end

  # Правка: как у формы бланка, два исхода и два кода.
  def update
    if @company.update(company_params)
      redirect_to company_path(@company), status: :see_other,
                  notice: "Дорога #{@company.code}: изменения внесены."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Снять дорогу с реестра.
  #
  # Удалось — 303 в реестр. Не 302: на `DELETE`, перенаправленный кодом 302,
  # браузер вправе повторить `DELETE` по новому адресу.
  #
  # Не удалось — модель отказала (`restrict_with_error`, s04e05): у дороги
  # перевозки, участки или расчёты. Это не «сделано, смотри там», поэтому не
  # 303, а 422 — и страница этой же дороги с причиной словами.
  def destroy
    if @company.destroy
      redirect_to companies_path, status: :see_other,
                  notice: "Дорога #{@company.code} убрана из реестра."
    else
      flash.now[:alert] = @company.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
    end
  end

  private

  # `find_by!` — тот же `find`, только по другому столбцу: нет дороги —
  # RecordNotFound — 404.
  def set_company
    @company = Company.find_by!(code: params[:code])
  end

  # Код — адрес дороги, и формой он не правится: в списке его нет, и
  # дописанный в запрос `company[code]` будет выброшен.
  def company_params
    params.expect(company: %i[name registered_on])
  end
end
