require "net/http"

# Книга выплат казначейства — со стороны конторы.
#
# Чужая система, как линия (s06e05): ей дают предел ожидания, её молчание —
# обрыв, и повторы решает задача, а не Net::HTTP.
module TreasuryBook
  class Down < StandardError; end

  OPEN_TIMEOUT = 1
  READ_TIMEOUT = 2

  module_function

  def url = URI(Rails.configuration.x.treasury_book)

  # Выплаты казны за месяц: [{ "delivery" => "NGS-0512", "receipt" => "НГС-7712", "kopecks" => 240000 }, …]
  def payments(month)
    response = Net::HTTP.start(url.host, url.port, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
                                                   max_retries: 0) do |http|
      http.request(Net::HTTP::Get.new("/payments?month=#{ERB::Util.url_encode(month)}"))
    end
    raise Down, "казначейство ответило #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("payments")
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET => error
    raise Down, "казначейство молчит: #{error.class}"
  end
end
