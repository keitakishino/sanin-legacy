class TradeCardOffersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event
  before_action :set_trade
  before_action :authorize_user_or_admin!
  before_action :set_trade_card_offer, only: [ :update, :destroy ]
  before_action :validate_trade_id_param, only: [ :update, :destroy ]

  def create
    @trade_card_offer = @trade.trade_card_offers.build(trade_card_offer_params)
    # Store trade_id for turbo_stream template context awareness
    # Only set @trade_id if current user is admin AND trade_id param is present
    # This prevents general users (even if they manually send trade_id param) from being treated as admin context
    @trade_id = current_user.role_admin? && params[:trade_id].present? ? params[:trade_id].to_i : nil
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
    # Store trade_id for turbo_stream template context awareness
    # Only set @trade_id if current user is admin AND trade_id param is present
    @trade_id = current_user.role_admin? && params[:trade_id].present? ? params[:trade_id].to_i : nil
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html { redirect_to trade_path(@trade.event), notice: "カード明細を削除しました" }
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_trade
    # For update/destroy actions: get trade from card_offer to ensure we get the correct trade
    # This allows authorize_user_or_admin! to properly check permissions and return 403 instead of 404
    if %w[update destroy].include?(action_name) && params[:id].present?
      trade_card_offer_temp = TradeCardOffer.find(params[:id])
      @trade = trade_card_offer_temp.trade
      raise ActiveRecord::RecordNotFound unless @trade.event_id == @event.id
    else
      # For create and other actions: get trade from event using existing logic
      if current_user.role_admin? && params[:trade_id].present?
        # For admin acting on another user's trade: validate trade_id matches the event_id in the URL
        @trade = Trade.find_by!(id: params[:trade_id], event_id: @event.id)
      else
        # General user, or admin acting on their own trade: resolve by current_user
        @trade = Trade.find_by!(event_id: @event.id, user_id: current_user.id)
      end
    end
  end

  def authorize_user_or_admin!
    unless @trade.user == current_user || current_user.role_admin?
      raise ForbiddenError
    end
  end

  def set_trade_card_offer
    @trade_card_offer = @trade.trade_card_offers.find(params[:id])
  end

  def validate_trade_id_param
    # Defense in Depth: Validate that the trade_id param (if provided) matches the actual trade
    # This prevents IDOR attacks where a user might try to manipulate a card detail record
    # by specifying a different trade_id
    if params[:trade_id].present? && params[:trade_id].to_i != @trade.id
      raise ActiveRecord::RecordNotFound
    end
  end

  def trade_card_offer_params
    permitted = [ :card_name, :quantity, :language, :condition, :foil, :frame, :pw_mark, :expansion_id, :note ]
    permitted << :amount if current_user.role_admin?
    params.require(:trade_card_offer).permit(permitted)
  end
end
