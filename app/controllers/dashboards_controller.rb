class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def show
    @my_proxy_orders = ProxyOrder.joins(:proxy_order_participants, :event)
                                  .where(proxy_order_participants: { user_id: current_user.id })
                                  .where(events: { discarded_at: nil })
                                  .includes(:event)
                                  .order("events.event_date DESC")
  end

  def incomplete_trades
    @incomplete_trades = current_user.trades
                                      .where(status: [ :pending, :in_progress ])
                                      .includes(:event, :trade_card_offers, :trade_card_wants)
                                      .order(created_at: :desc)
                                      .limit(3)
    render :incomplete_trades, layout: false
  end
end
