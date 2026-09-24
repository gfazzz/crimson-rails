# Отдать телеграмму на линию.
#
# Задача — записка работнику: «отдай на линию телеграмму № такой-то». В
# записке ссылка на телеграмму, а не её копия: работник возьмёт телеграмму
# из книги такой, какая она будет к его приходу, — с поправкой, если её
# внесли, и никакой, если телеграмму отозвали.
class DispatchJob < ApplicationJob
  # Телеграммы нет — отозвали, пока записка лежала. Отдавать нечего, и
  # повторять незачем: не ошибка, а исход.
  discard_on ActiveJob::DeserializationError

  def perform(telegram)
    # Уже ушла — второй раз не отдаём. Записку могли положить дважды.
    return unless telegram.pending?

    number = TelegraphLine.deliver(telegram)
    telegram.update!(state: :sent, number: number, sent_at: Time.current)
  end
end
