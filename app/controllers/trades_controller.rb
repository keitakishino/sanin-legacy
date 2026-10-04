class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_or_create_trade, only: [ :show ]

  def show
    # @trade is set by set_or_create_trade
    @offers_list = CardDetailList.new(@trade.trade_card_offers.includes(:expansion), prefix: "offers", params: params)
    @wants_list = CardDetailList.new(@trade.trade_card_wants.includes(:expansion), prefix: "wants", params: params)
    @list_params = request.query_parameters.slice(*CardDetailList.state_keys("offers"), *CardDetailList.state_keys("wants")).compact_blank
  end

  private

  def set_or_create_trade
    @event = Event.find(params[:event_id])
    @trade = Trade.find_or_create_by(event: @event, user: current_user) do |trade|
      trade.status = :pending
    end
    authorize_user!
  end

  def authorize_user!
    redirect_to events_path, alert: "権限がありません" unless @trade.user == current_user
  end
end
