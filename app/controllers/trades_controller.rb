class TradesController < ApplicationController
  include CardDetailListAssignment

  before_action :authenticate_user!
  before_action :set_or_create_trade, only: [ :show ]
  before_action :assign_card_detail_lists, only: [ :show ]

  def show
    # @trade, @offers_list, @wants_list, @list_params are set by callbacks
  end

  private

  def set_or_create_trade
    @event = Event.find(params[:event_id])
    @trade = Trade.find_or_create_by(event: @event, user: current_user) do |trade|
      trade.status = :pending
    end
    record_audit("trade.create", target: @trade, details: { event_id: @event.id }) if @trade.previously_new_record?
    authorize_user!
  end

  def authorize_user!
    redirect_to events_path, alert: "権限がありません" unless @trade.user == current_user
  end
end
