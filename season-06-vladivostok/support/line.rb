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
#
# Линию можно спросить о телеграмме по её номеру: `GET /messages/ВЛ-4401` —
# 200 и что с ней, если это телеграмма этой линии; 404, если нет.
#
#   line.knows!("НГС-7712")        — линия передавала телеграмму с этим номером
#                                    (квитанции из Нагасаки приходят не от нас)
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
        @known = []
        @counter = 4400
        # Поколение линии. Запрос, задумавшийся в прошлой проверке, может
        # проснуться уже в следующей; то, что он принёс, следующей не касается.
        @generation = (@generation || 0) + 1
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
      Minitest.after_run { @server.stop(false) } if defined?(Minitest)
      self
    end

    # ─── что линия сделает со следующими приёмами ──────────────────────────

    def break!(times = 1) = plan(:down, times)
    def reject!(times = 1) = plan(:reject, times)
    def stall!(seconds, times = 1) = plan([:stall, seconds], times)
    def lose_answer!(times = 1) = plan(:lose, times)
    def garble!(times = 1) = plan(:garble, times)

    def knows!(*numbers)
      @lock.synchronize { numbers.each { |number| @known << number } }
      self
    end

    def plan(what, times)
      @lock.synchronize { times.times { @plan << what } }
      self
    end

    # ─── приём ─────────────────────────────────────────────────────────────

    def call(env)
      request = Request.new(verb: env["REQUEST_METHOD"], path: env["PATH_INFO"],
                            headers: headers_of(env), body: env["rack.input"]&.read)
      kind = if request.verb == "POST" && request.path == "/messages" then :deliver
             elsif request.verb == "GET" && request.path.start_with?("/messages/") then :trace
             end
      generation = nil
      planned = @lock.synchronize do
        generation = @generation
        @requests << request
        @plan.shift if kind
      end
      return answer(404, error: "not_found") unless kind

      case planned
      when :down then return answer(503, error: "line_down")
      when :reject then return answer(422, error: "no_such_addressee")
      when :garble then return answer(201, nummer: "?")
      when Array then sleep planned.last
      end

      return answer(410, error: "stale") unless @lock.synchronize { generation == @generation }
      return trace(request) if kind == :trace

      response = accept(request)
      sleep 6 if planned == :lose # принято и передано — ответ не дойдёт: клиент бросит ждать раньше
      response
    end

    private

    # Справка о телеграмме. Лежащая или задумавшаяся линия отвечает на справку
    # так же, как на приём: план расходуется и здесь.
    def trace(request)
      number = URI.decode_www_form_component(request.path.delete_prefix("/messages/"))
      known = @lock.synchronize { @known.include?(number) || @accepted.any? { |item| item[:number] == number } }
      return answer(404, error: "not_ours") unless known

      answer(200, number: number, state: "transmitted")
    end

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
