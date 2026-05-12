class TradesController < ActionController::Base
  def new
    @trade = Trade.new
  end

  def create
    @trade = Trade.create!(trade_params)
    redirect_to new_wishlists_trade_path(@trade)
  end

  def new_wishlists
    @trade = Trade.find(params[:id])
  end

  def edit_wishlists
    @trade = Trade.find(params[:id])
    @wishlists = @trade.wishlists
  end

  private

  def trade_params
    params.require(:trade).permit(:name, :contact, :contact_account, :residue, :memo)
  end
end
