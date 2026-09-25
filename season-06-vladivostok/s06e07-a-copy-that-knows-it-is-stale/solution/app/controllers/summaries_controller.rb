# Сводка поставок за месяц — из копии, если копия не устарела.
class SummariesController < ApplicationController
  def show
    @summary = Delivery.cached_summary(params[:month])
  end
end
