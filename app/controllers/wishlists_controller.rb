class WishlistsController < ActionController::Base
  def index
    @trade = Trade.find(params[:trade_id])
    @wishlists = @trade.wishlists
  end
end
