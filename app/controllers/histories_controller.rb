class HistoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @trades = Trade.where(user: current_user, status: [ :completed, :cancelled ])
                   .order(completed_at: :desc, updated_at: :desc)
                   .includes(:event, :user, :trade_card_offers, :trade_card_wants)
                   .page(params[:page])
                   .per(20)
  end
end
