class HistoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @trades = Trade.where(user: current_user, status: [ :completed, :cancelled ])
                   .order(Arel.sql("COALESCE(trades.completed_at, trades.updated_at) DESC"))
                   .includes(:event, :user, :trade_card_offers, :trade_card_wants)
                   .page(params[:page])
                   .per(20)
  end
end
