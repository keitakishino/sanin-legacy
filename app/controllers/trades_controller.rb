class TradesController < ActionController::Base
  def new
    @trade = Trade.new
    @trade.trade_cards.new
  end

  def create

  end
end
