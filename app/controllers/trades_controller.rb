class TradesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_or_create_trade, only: [ :show ]

  def show
    # @trade is set by set_or_create_trade
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
