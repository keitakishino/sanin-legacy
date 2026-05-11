class TradesController < ActionController::Base
  def new
    @trade = Trade.new
  end

  def create
    @trade = Trade.create!(trade_params)
    redirect_to new_trade_wishlist_path(@trade)
  end

  private

  def trade_params
    params.require(:trade).permit(:name, :contact, :contact_account, :residue, :memo)
  end
end
