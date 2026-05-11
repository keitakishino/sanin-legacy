class WishlistsController < ActionController::Base
  def new
    @trade = Trade.find(params[:trade_id])
  end
end
