# Книга поставок дома: пароход, шпалы, квитанции, выплата.
class DeliveriesController < ApplicationController
  def index
    @deliveries = Delivery.order(:reference)
  end
end
