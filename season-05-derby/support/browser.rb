# CRIMSON RAILS — проверки сезона 5 в настоящем браузере.
#
# Две серии сезона проверяют то, чего не видно по ответу сервера: что страница
# **не перезагрузилась**. Turbo Drive заменяет тело страницы, не трогая окна;
# Stimulus подключает поведение к разметке, которая пришла без перезагрузки.
# Увидеть это можно только там, где это происходит, — в браузере.
#
# Приём один: перед действием на окне ставится метка. Перезагрузка стирает
# всё, что было в окне, и метку тоже; Turbo её не трогает. Метка на месте —
# страница не перезагружалась.
#
# Браузер — Chrome без окна, через Selenium, как в системных тестах Rails.
# Драйвер под установленный Chrome Selenium найдёт сам. Приложение поднимает
# Capybara — в этом же процессе, на свободном порту.

require_relative "check"
require "capybara/minitest"
require "selenium-webdriver"

Capybara.register_driver(:crimson_chrome) do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV["CRIMSON_CHROME"] if ENV["CRIMSON_CHROME"]
  %w[--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage
     --window-size=1200,900 --lang=ru].each { |argument| options.add_argument(argument) }
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
Capybara.server = :puma, { Silent: true }
Capybara.app = Rails.application
Capybara.default_max_wait_time = 5

module Crimson
  class BrowserTest < Test
    include Capybara::Minitest::Assertions

    MARK = "не перезагружалась"

    # Один браузер на прогон: поднимать его на каждую проверку — секунды
    # впустую. Хранится у самого BrowserTest, а не у наследников.
    class << self
      attr_reader :failure

      def browser
        return BrowserTest.shared if BrowserTest.shared || BrowserTest.failure

        BrowserTest.start
      end

      def shared = @shared

      def start
        @shared = Capybara::Session.new(:crimson_chrome, Rails.application)
        @shared.visit("/up")
        @shared
      rescue StandardError => error
        @failure = error
        @shared = nil
      end
    end

    Minitest.after_run { BrowserTest.shared&.driver&.quit }

    def browser
      self.class.browser || flunk(<<~TEXT)
        Браузер не поднялся: #{BrowserTest.failure&.class}: #{BrowserTest.failure&.message.to_s.lines.first&.strip}

        Этой серии нужен Chrome (или Chromium). Драйвер под него Selenium найдёт
        сам; если в PATH лежит chromedriver другой версии — он помешает.
        Путь к нестандартному Chrome — в CRIMSON_CHROME.
      TEXT
    end

    # Capybara ищет сессию под именем `page`.
    def page = browser

    def setup
      super
      browser.reset_session!
    end

    # ─── метка на окне ────────────────────────────────────────────────────

    def mark_window!
      browser.execute_script("window.__crimson = #{MARK.to_json}")
    end

    def reloaded?
      browser.evaluate_script("window.__crimson") != MARK
    end

    def assert_not_reloaded(what)
      refute reloaded?, "#{what} — и страница перезагрузилась. Turbo заменяет содержимое, " \
                        "не трогая окна; перезагрузка — значит, Turbo не справился и сдался."
    end

    def visit(path)
      browser.visit(path)
      assert browser.evaluate_script("typeof window.Turbo === 'object'"),
             "На странице #{path} нет Turbo: окно работает как в прошлом веке. Turbo " \
             "подключается в app/javascript/application.js и в макете (`javascript_importmap_tags`)."
    end
  end
end
