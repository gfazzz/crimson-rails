class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Отказ — в формате спрашивающего (s05e11). Телеграфный аппарат, спросивший
  # JSON, получает на «нет такой дороги» JSON с кодом 404, а не страницу,
  # которую ему не разобрать. Человеку по-прежнему отвечает страница 404:
  # для него исключение идёт дальше, как шло всегда.
  rescue_from ActiveRecord::RecordNotFound do |error|
    raise error unless request.format.json?

    render json: { error: "not_found", message: "Такой записи в реестре нет." }, status: :not_found
  end
end
