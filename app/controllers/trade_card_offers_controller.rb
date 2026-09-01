class TradeCardOffersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trade
  before_action :authorize_user_or_admin!
  before_action :set_trade_card_offer, only: [ :update, :destroy ]

  def create
    @trade_card_offer = @trade.trade_card_offers.build(trade_card_offer_params)
    if @trade_card_offer.save
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to trade_path(@trade.event), notice: "カード明細を追加しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { redirect_to trade_path(@trade.event), alert: @trade_card_offer.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    if @trade_card_offer.update(trade_card_offer_params)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to trade_path(@trade.event), notice: "カード明細を更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { redirect_to trade_path(@trade.event), alert: @trade_card_offer.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @trade_card_offer.destroy
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html { redirect_to trade_path(@trade.event), notice: "カード明細を削除しました" }
    end
  end

  private

  def set_trade
    @trade = Trade.find_by!(event_id: params[:event_id], user_id: current_user.id)
  end

  def authorize_user_or_admin!
    unless @trade.user == current_user || current_user.role_admin?
      head :forbidden
    end
  end

  def set_trade_card_offer
    @trade_card_offer = @trade.trade_card_offers.find(params[:id])
  end

  def trade_card_offer_params
    permitted = [ :card_name, :quantity, :language, :condition, :foil, :frame, :pw_mark, :expansion_id, :note ]
    permitted << :amount if current_user.role_admin?
    params.require(:trade_card_offer).permit(permitted)
  end
end
