require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Ledger
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Контора — во Владивостоке, и её часы — владивостокские. В 1892 году это
    # местное среднее время, на 8 часов 47 минут 31 секунду впереди Гринвича:
    # поясного времени в России ещё нет (s06e10).
    config.time_zone = "Vladivostok"
    # config.eager_load_paths << Rails.root.join("extras")

    # Окно читают в Дерби: отказы моделей и подписи форм — по-русски.
    # Локаль ведёт курс (config/locales/ru.yml), а не студент.
    config.i18n.default_locale = :ru
    config.i18n.available_locales = %i[ru en]

    # Сезон 6. Очередь — таблицы Solid Queue в той же базе, что реестр
    # (db/migrate/18920512…). Работу делает не запрос, а работник очереди.
    config.active_job.queue_adapter = :solid_queue

    # Линия Большого Северного: станция на Светланской. В проверках адрес
    # подменяется поддельной линией (support/line.rb).
    config.x.telegraph_line = ENV.fetch("TELEGRAPH_LINE", "http://127.0.0.1:4750")

    # Общий секрет с линией: им линия подписывает то, что шлёт конторе сама
    # (s06e06). На проде — из credentials, а не из кода; здесь — учебный.
    config.x.line_secret = ENV.fetch("LINE_SECRET") { "svetlanskaya-1892-uchebny" }

    # Книга выплат казначейства — у казначейской части, по проводу (s06e11).
    # В проверках — поддельная (support/treasury.rb).
    config.x.treasury_book = ENV.fetch("TREASURY_BOOK", "http://127.0.0.1:4760")
  end
end
