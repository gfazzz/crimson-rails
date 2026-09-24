class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # TODO: отказ — в формате спрашивающего. Аппарат, спросивший JSON, на «нет
  #       такой записи» получает JSON с кодом 404, а не страницу. Человеку —
  #       по-прежнему страница 404.
end
