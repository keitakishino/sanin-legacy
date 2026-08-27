class WishlistsController < ApplicationController
  def index
    @trade = Trade.find(params[:trade_id])
    @wishlists = @trade.wishlists
  end
end
