# CRIMSON RAILS — поддельная книга казначейства для проверок s06e11.
#
# Казначейская часть постройки ведёт свою книгу выплат — и даёт её конторе
# по проводу: `GET /payments?month=1892-05` — JSON, выплата на строку. Это
# чужая система, как линия Большого Северного (s06e05): она отвечает,
# ложится и задумывается.
#
#   treasury.book!("1892-05", [{ delivery: "NGS-0512", receipt: "НГС-7712", kopecks: 240000 }, …])
#   treasury.break!(2)            — два следующих ответа — 503
#   treasury.stall!(4)            — следующий ответ задержать на 4 секунды
#   treasury.requests             — что спросили
require "puma"
require "json"

module Crimson
  class Treasury
    attr_reader :requests

    def self.shared = (@shared ||= new.tap(&:start))

    def initialize
      @lock = Mutex.new
      reset!
    end

    def reset!
      @lock.synchronize do
        @books = Hash.new { |all, month| all[month] = [] }
        @plan = []
        @requests = []
        @generation = (@generation || 0) + 1
      end
    end

    def url = "http://127.0.0.1:#{@port}"

    def start(port = 0)
      @server = Puma::Server.new(method(:call), nil, min_threads: 0, max_threads: 4,
                                 log_writer: Puma::LogWriter.null)
      @server.add_tcp_listener("127.0.0.1", port)
      @port = @server.connected_ports.first
      @server.run
      Minitest.after_run { @server.stop(false) } if defined?(Minitest)
      self
    end

    def book!(month, rows)
      @lock.synchronize { @books[month].concat(rows.map { |row| row.transform_keys(&:to_s) }) }
      self
    end

    def break!(times = 1) = plan(:down, times)
    def stall!(seconds, times = 1) = plan([:stall, seconds], times)

    def plan(what, times)
      @lock.synchronize { times.times { @plan << what } }
      self
    end

    def call(env)
      query = Rack::Utils.parse_query(env["QUERY_STRING"].to_s)
      generation = nil
      planned = @lock.synchronize do
        generation = @generation
        @requests << { path: env["PATH_INFO"], month: query["month"] }
        @plan.shift
      end
      return answer(404, error: "not_found") unless env["REQUEST_METHOD"] == "GET" && env["PATH_INFO"] == "/payments"

      case planned
      when :down then return answer(503, error: "treasury_closed")
      when Array then sleep planned.last
      end
      return answer(410, error: "stale") unless @lock.synchronize { generation == @generation }

      rows = @lock.synchronize { @books[query["month"].to_s].map(&:dup) }
      answer(200, month: query["month"], payments: rows)
    end

    private

    def answer(code, body) = [code, { "content-type" => "application/json" }, [body.to_json]]
  end
end
