# Отдать телеграмму на линию.
#
# Задача — записка работнику: «отдай на линию телеграмму № такой-то». В
# записке ссылка на телеграмму, а не её копия (s06e01).
class DispatchJob < ApplicationJob
  # Своя очередь — у телеграфа свой работник: линия принимает по одной, и
  # телеграммы не должны стоять за чужой работой (config/queue.yml).
  queue_as :telegraph

  # Квитанции казне — вперёд прочих: по ним платят. У Solid Queue меньшее
  # число — раньше.
  TREASURY = 0
  ROUTINE = 10
  queue_with_priority { arguments.first.delivery_id ? TREASURY : ROUTINE }

  # Телеграммы нет — отозвали, пока записка лежала (s06e01).
  discard_on ActiveJob::DeserializationError

  # Отдать телеграмму тогда, когда станция её примет: днём — сразу, ночью —
  # к открытию окошка. Записка при этом ложится сейчас: утром её возьмут из
  # таблицы, а не из памяти конторы.
  def self.hand_in(telegram)
    set(wait_until: TelegraphLine.opens_at(Time.current)).perform_later(telegram)
  end

  def perform(telegram)
    return unless telegram.pending?

    number = TelegraphLine.deliver(telegram)
    telegram.update!(state: :sent, number: number, sent_at: Time.current)
  end
end
