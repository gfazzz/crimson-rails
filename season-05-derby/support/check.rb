# CRIMSON RAILS — общая библиотека проверок сезона 5.
#
# Контракт сезона: **проверяется ответ, а не шаблон.** Код ответа, адрес
# перенаправления, тип содержимого, форма документа, который пришёл, — и то,
# как на них отзывается Turbo. Не проверяется, какие теги стоят в `.erb` и что
# «страница отрендерилась»: страница с кодом 200 и пустым телом тоже
# отрендерилась.
#
# Запросы идут в процессе, через стойку Rack, без сервера и без браузера:
# ровно так их видит приложение. Turbo — это протокол поверх HTTP, и у него
# есть серверная половина: запрос фрейма приходит с заголовком `Turbo-Frame`,
# поток — с типом `text/vnd.turbo-stream.html`, неудачная форма обязана
# вернуть 422, удачная — перенаправить с 303. Всё это видно отсюда.
#
# Чего отсюда не видно — что страница не перезагрузилась. Для двух серий
# сезона, где предмет именно это, есть `support/browser.rb` и настоящий
# браузер (`make test-visual`).
#
# Приложение сезона лежит рядом; путь можно задать снаружи (LEDGER_APP) — на
# этом держится прогон эталона.

module Crimson
  SERVICE_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  # Типы, с которыми Turbo ходит к серверу. Порядок как у самого Turbo:
  # поток первым, разметка — запасным вариантом.
  TURBO_STREAM = "text/vnd.turbo-stream.html"
  TURBO_ACCEPT = "#{TURBO_STREAM}, text/html, application/xhtml+xml".freeze

  class << self
    def app
      @app ||= File.expand_path(ENV.fetch("LEDGER_APP") { File.join(__dir__, "..", "app") })
    end

    def boot!
      return if @booted

      ENV["RAILS_ENV"] = "test"
      ENV["BUNDLE_GEMFILE"] = File.join(app, "Gemfile")
      require "bundler/setup"
      require "minitest/autorun"
      require File.join(app, "config/environment")
      require "action_dispatch/testing/integration"
      require "nokogiri"

      begin
        ActiveRecord::Migration.maintain_test_schema!
      rescue ActiveRecord::PendingMigrationError
        abort <<~TEXT
          В db/migrate есть миграции, которых нет в схеме. Прогони:

              cd #{app} && bin/rails db:prepare
        TEXT
      end

      ActiveRecord::Migration.verbose = false
      @booted = true
    end
  end
end

Crimson.boot!

module Crimson
  # Общий предок проверок сезона.
  class Test < Minitest::Test
    # ─── запрос ───────────────────────────────────────────────────────────
    #
    # Сессия — то же, что в `ActionDispatch::IntegrationTest`: стойка Rack,
    # куки, перенаправления. Перенаправления **не** выполняются сами: их код и
    # адрес — часть ответа, и проверять надо именно их.

    def session
      @session ||= ActionDispatch::Integration::Session.new(Rails.application)
    end

    %i[get post patch put delete].each do |verb|
      define_method(verb) do |path, params: nil, headers: {}|
        session.public_send(verb, path, params: params, headers: headers)
        response
      end
    end

    def response = session.response
    def status = response.status
    def location = response.location
    def media_type = response.media_type

    # Пройти по перенаправлению — один шаг, как браузер.
    def follow!
      flunk "Ответ #{status} — не перенаправление, идти некуда." unless response.redirect?
      session.follow_redirect!
      response
    end

    # ─── Turbo со стороны сервера ─────────────────────────────────────────

    # Запрос, который Turbo шлёт за содержимым фрейма.
    def frame(path, id)
      get(path, headers: { "Turbo-Frame" => id })
    end

    # Отправка формы так, как её отправляет Turbo: поток первым в `Accept`.
    def turbo(verb, path, params: nil)
      public_send(verb, path, params: params, headers: { "Accept" => TURBO_ACCEPT })
    end

    # Действия потока из ответа: что сделать и с чем.
    #
    # Цель у действия либо одна (`target` — идентификатор), либо набор
    # (`targets` — селектор). Шаблон — содержимое `<template>`, то есть то,
    # что будет вставлено.
    def streams(body = response.body)
      Nokogiri::HTML5.fragment(body).css("turbo-stream").map do |node|
        template = node.at_css("template")
        { action: node["action"], target: node["target"], targets: node["targets"],
          template: template && Nokogiri::HTML5.fragment(template.inner_html) }
      end
    end

    # ─── что пришло ───────────────────────────────────────────────────────

    # Разбор ответа по тем же правилам, по каким его разбирает браузер.
    def page(body = response.body) = Nokogiri::HTML5(body)

    def texts(selector, doc = page) = doc.css(selector).map { |node| node.text.squish }

    # Ссылки ответа: адреса, без хоста.
    def hrefs(doc = page) = doc.css("a[href]").map { |node| URI(node["href"]).path }

    # ─── формы ────────────────────────────────────────────────────────────
    #
    # Форма проверяется не тем, какие поля в шаблоне, а тем, что уйдёт, если
    # её отправить: форма из ответа отправляется так, как её отправит браузер,
    # — по её адресу, её глаголом (с учётом скрытого `_method`), со всеми её
    # скрытыми полями и значениями, которые в ней уже стоят.

    def form_on_page(doc = page)
      doc.at_css("main form") || flunk("В главной части страницы нет формы.")
    end

    # Значения поля формы, как их пошлёт браузер.
    def form_fields(form = form_on_page)
      form.css("input[name], select[name], textarea[name]").each_with_object({}) do |node, fields|
        next if %w[submit button image reset file].include?(node["type"])
        next if %w[checkbox radio].include?(node["type"]) && !node.key?("checked")

        fields[node["name"]] =
          case node.name
          when "select" then (node.at_css("option[selected]") || node.at_css("option"))&.[]("value")
          when "textarea" then node.text
          else node["value"]
          end
      end
    end

    # Заполнить форму по именам полей и отправить.
    #
    #   submit({ reference: "B-0992" }, scope: :consignment)
    #
    # Поле, которого в форме нет, — несделанная работа: форма обещает
    # контроллеру то, что он получит. `inject:` — поля сверх формы: так
    # подделывают запрос, и сильные параметры обязаны это выдержать.
    def submit(values = {}, scope: nil, form: form_on_page, inject: {}, headers: {})
      fields = form_fields(form)
      values.each do |key, value|
        name = scope ? "#{scope}[#{key}]" : key.to_s
        flunk "В форме нет поля #{name}. Форма — обещание контроллеру: что в ней есть, то " \
              "он и получит." unless fields.key?(name)
        fields[name] = value.to_s
      end
      inject.each { |name, value| fields[name.to_s] = value.to_s }

      verb = (fields.delete("_method") || form["method"] || "get").downcase.to_sym
      action = form["action"].to_s.empty? ? session.request.path : URI(form["action"]).path
      public_send(verb, action, params: fields, headers: headers)
    end

    # ─── сколько спросили у базы ───────────────────────────────────────────

    # Запросы к таблице за время блока — по тем же уведомлениям, по которым
    # пишет журнал Rails (s04e07).
    def queries(table = nil, kind: "SELECT")
      seen = []
      probe = lambda do |*, payload|
        sql = payload[:sql].to_s
        next unless sql.start_with?(kind)

        seen << sql if table.nil? || sql.include?(%("#{table}"))
      end
      ActiveSupport::Notifications.subscribed(probe, "sql.active_record") { yield }
      seen
    end

    # ─── гонка ────────────────────────────────────────────────────────────

    # Соперник в окне гонки: строка появляется в базе после того, как
    # проверка уникальности посмотрела и ничего не нашла, и до того, как
    # запись легла. Ровно то окно, о котором s04e04: валидация его не видит,
    # индекс — видит.
    def with_rival(table, column, sql)
      entered = false
      probe = lambda do |*, payload|
        text = payload[:sql].to_s
        next if entered || !text.start_with?(%(SELECT 1 AS one FROM "#{table}")) || !text.include?(%("#{column}"))

        entered = true
        ActiveRecord::Base.lease_connection.execute(sql)
      end
      ActiveSupport::Notifications.subscribed(probe, "sql.active_record") { yield }
      flunk "Соперник не вошёл в окно: проверки уникальности по #{table}.#{column} не было." unless entered
    end

    # ─── маршруты ─────────────────────────────────────────────────────────

    # Куда маршрут ведёт: «контроллер#действие» или nil, если маршрута нет.
    #
    # Спрашивается таблица маршрутов, а не контроллер: так видно обещание, а не
    # то, как его выполнили.
    def route(verb, path)
      found = Rails.application.routes.recognize_path(path, method: verb)
      "#{found[:controller]}##{found[:action]}"
    rescue ActionController::RoutingError
      nil
    end

    # Все маршруты, ведущие в контроллер, — парами «глагол путь».
    def routes_to(controller)
      Rails.application.routes.routes.filter_map do |item|
        next unless item.defaults[:controller] == controller.to_s

        [item.verb.to_s, item.path.spec.to_s.delete_suffix("(.:format)"), item.defaults[:action]]
      end
    end

    def helpers = Rails.application.routes.url_helpers

    # Адрес по имени маршрута. Если имени нет — это несделанная работа, и о
    # ней говорится словами, а не трассировкой.
    def path(name, *args)
      helpers.public_send("#{name}_path", *args)
    rescue NoMethodError => error
      raise unless error.name.to_s == "#{name}_path"

      flunk "Нет маршрута с именем «#{name}»: помощника #{name}_path не существует. " \
            "Имена маршрутам даёт `resources` в config/routes.rb; адрес, собранный " \
            "строкой, разойдётся с таблицей при первой правке."
    end

    # ─── данные ───────────────────────────────────────────────────────────
    #
    # Сезон про окно, а не про базу: строки заводятся моделями сезона 4 — их
    # валидации там уже проверены.

    def wipe!
      %w[settlements legs consignments entries companies].each do |name|
        ActiveRecord::Base.lease_connection.execute("DELETE FROM #{name}")
      end
    end

    def road(code, name = "Дорога #{code}", **over)
      Company.create!(code: code, name: name, **over)
    end

    def shipment(company, reference, **over)
      Consignment.create!(company: company, reference: reference, description: "чай, ящиков 12",
                          sent_on: Date.new(1891, 10, 5), pence: 960, weight_lb: 336, **over)
    end

    # ─── сообщения ────────────────────────────────────────────────────────

    # Minitest дописывает к сообщению точку; сообщения сезона — предложения и
    # кончаются своей. Без этого выходит «..».
    def message(msg = nil, ending = nil, &default)
      super(msg.is_a?(String) ? msg.chomp(".") : msg, ending, &default)
    end

    def assert_status(expected, message = nil)
      return pass if status == expected

      flunk [message, "Ожидался код #{expected}, пришёл #{status}#{" → #{location}" if location}."]
              .compact.join("\n")
    end
  end
end
