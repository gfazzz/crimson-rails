# Отдать телеграмму на линию.
#
# Задача — записка работнику: «отдай на линию телеграмму № такой-то». В
# записке ссылка на телеграмму, а не её копия (s06e01).
class DispatchJob < ApplicationJob
  # TODO: своя очередь — `telegraph`.

  # TODO: квитанции казне (у телеграммы есть поставка) — вперёд прочих.
  #       У Solid Queue меньшее число приоритета — раньше.

  # Телеграммы нет — отозвали, пока записка лежала (s06e01).
  discard_on ActiveJob::DeserializationError

  # Отдать телеграмму тогда, когда станция её примет.
  def self.hand_in(telegram)
    # TODO: днём — сразу; ночью — к открытию окошка (TelegraphLine.opens_at).
    #       Записка ложится сейчас.
    perform_later(telegram)
  end

  def perform(telegram)
    return unless telegram.pending?

    number = TelegraphLine.deliver(telegram)
    telegram.update!(state: :sent, number: number, sent_at: Time.current)
  end
end
