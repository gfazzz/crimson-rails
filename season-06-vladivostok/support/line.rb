# CRIMSON RAILS — поддельная линия Большого Северного для проверок сезона 6.
#
# Настоящая станция стоит на Светланской; в проверке её место занимает этот
# сервер. Он поднимается в том же процессе, на свободном порту, и отвечает
# так, как отвечает линия: принял — номер, порвалась — 503, не туда — 422,
# задумалась — молчит.
#
# Сервер настоящий, по сокету: клиент конторы (`TelegraphLine`) не знает, что
# говорит с подделкой. Поэтому пределы ожидания, коды и заголовки проверяются
# ровно такими, какими их увидит станция.
#
# Что линия умеет:
#
#   line.accepted                  — что линия приняла к передаче (по порядку)
#   line.requests                  — все запросы, как они пришли
#   line.break!(2)                 — два следующих приёма ответить 503
#   line.reject!                   — следующий приём отвергнуть: 422
#   line.stall!(3)                 — следующий приём держать три секунды
#   line.lose_answer!              — принять, передать — и не ответить (обрыв после приёма)
#   line.garble!                   — принять и ответить 201 без номера: ответ, которого
#                                    контора не ждёт
#
# Линия помнит номер отправления (заголовок `Idempotency-Key`): телеграмму с
# тем же номером она второй раз не передаёт и отвечает прежним номером. Так
# работают настоящие линии, и на этом держится s06e05.
require "puma"
require "puma/configuration"
require "json"

module Crimson
  class Line
    Request = Struct.new(:verb, :path, :headers, :body, keyword_init: true) do
      def json = JSON.parse(body.to_s)
      def key = headers["idempotency-key"]
    end

    attr_reader :accepted, :requests

    def self.shared = (@shared ||= new.tap(&:start))

    def initialize
      @lock = Mutex.new
      reset!
    end

    def reset!
      @lock.synchronize do
        @accepted = []
        @requests = []
        @by_key = {}
        @plan = []
        @counter = 4400
      end
    end

    def url = "http://127.0.0.1:#{@port}"

    def start(port = 0)
      @server = Puma::Server.new(method(:call), nil, min_threads: 0, max_threads: 8,
                                 log_writer: Puma::LogWriter.null)
      @server.add_tcp_listener("127.0.0.1", port)
      @port = @server.connected_ports.first
      @server.run
      # Не `at_exit`: минитест сам запускает проверки из `at_exit`, и
      # остановка, записанная позже, сработала бы раньше них.
      Minitest.after_run { @server.stop(true) } if defined?(Minitest)
      self
    end

    # ─── что линия сделает со следующими приёмами ──────────────────────────

    def break!(times = 1) = plan(:down, times)
    def reject!(times = 1) = plan(:reject, times)
    def stall!(seconds, times = 1) = plan([:stall, seconds], times)
    def lose_answer!(times = 1) = plan(:lose, times)
    def garble!(times = 1) = plan(:garble, times)

    def plan(what, times)
      @lock.synchronize { times.times { @plan << what } }
      self
    end

    # ─── приём ─────────────────────────────────────────────────────────────

    def call(env)
      request = Request.new(verb: env["REQUEST_METHOD"], path: env["PATH_INFO"],
                            headers: headers_of(env), body: env["rack.input"]&.read)
      what = @lock.synchronize do
        @requests << request
        request.path == "/messages" && request.verb == "POST" ? @plan.shift : :other
      end

      case what
      when :other then answer(404, error: "not_found")
      when :down then answer(503, error: "line_down")
      when :reject then answer(422, error: "no_such_addressee")
      when Array
        sleep what.last
        accept(request)
      when :lose
        accept(request)
        sleep 30 # ответ не дойдёт: клиент бросит ждать раньше
      when :garble then answer(201, nummer: "?")
      else accept(request)
      end
    end

    private

    def accept(request)
      number = @lock.synchronize do
        key = request.key
        if key && @by_key.key?(key)
          @by_key[key]
        else
          @counter += 1
          number = "ВЛ-#{@counter}"
          @accepted << { number: number, key: key, **request.json.transform_keys(&:to_sym) }
          @by_key[key] = number if key
          number
        end
      end
      answer(201, number: number)
    end

    def answer(code, body) = [code, { "content-type" => "application/json" }, [body.to_json]]

    def headers_of(env)
      env.each_with_object({}) do |(name, value), all|
        next unless name.start_with?("HTTP_")

        all[name.delete_prefix("HTTP_").downcase.tr("_", "-")] = value
      end
    end
  end
end

# Запуск отдельно — линия для конторы в разработке, на том адресе, где контора
# её ждёт по умолчанию (config.x.telegraph_line):
#
#   cd app && bundle exec ruby ../support/line.rb
if $PROGRAM_NAME == __FILE__
  line = Crimson::Line.new.start(4750)
  puts "Линия Большого Северного слушает #{line.url}. Ctrl+C — снять."
  seen = 0
  loop do
    sleep 1
    line.accepted.drop(seen).each { |item| puts "принято #{item[:number]} → #{item[:to]}: #{item[:body]}" }
    seen = line.accepted.size
  end
end
