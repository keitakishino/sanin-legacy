class TradeCardWantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trade
  before_action :authorize_user_or_admin!
  before_action :set_trade_card_want, only: [ :update, :destroy ]

  def create
    @trade_card_want = @trade.trade_card_wants.build(trade_card_want_params)
    if @trade_card_want.save
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to trade_path(@trade.event), notice: "カード明細を追加しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { redirect_to trade_path(@trade.event), alert: @trade_card_want.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    if @trade_card_want.update(trade_card_want_params)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to trade_path(@trade.event), notice: "カード明細を更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { redirect_to trade_path(@trade.event), alert: @trade_card_want.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @trade_card_want.destroy
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html { redirect_to trade_path(@trade.event), notice: "カード明細を削除しました" }
    end
  end

  private

  def set_trade
    if current_user.role_admin?
      @trade = Trade.find_by!(event_id: params[:event_id])
    else
      @trade = Trade.find_by!(event_id: params[:event_id], user_id: current_user.id)
    end
  end

  def authorize_user_or_admin!
    unless @trade.user == current_user || current_user.role_admin?
      head :forbidden
    end
  end

  def set_trade_card_want
    @trade_card_want = @trade.trade_card_wants.find(params[:id])
  end

  def trade_card_want_params
    permitted = [ :card_name, :quantity, :language, :foil, :frame, :expansion_id, :note, conditions: [] ]
    permitted << :amount if current_user.role_admin?
    params.require(:trade_card_want).permit(permitted)
  end
end
