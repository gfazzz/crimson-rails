# Табло причала на Первой речке: где сейчас каждая поставка.
#
# Табло смотрят, а не обновляют: всё, что на нём меняется, приходит само,
# потоком Turbo по кабелю (Delivery, «табло причала»).
class BoardController < ApplicationController
  def show
    @deliveries = Delivery.order(:reference)
  end
end
