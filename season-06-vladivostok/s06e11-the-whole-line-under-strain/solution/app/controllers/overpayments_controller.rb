# Переплаты казны за месяц — то, что казна выплатила сверх одного раза на
# поставку.
class OverpaymentsController < ApplicationController
  def show
    @month = params[:month]
    @overpayments = Overpayment.where(month: @month).includes(:delivery).order(:id)
  end
end
