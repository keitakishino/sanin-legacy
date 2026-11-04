class HistoriesController < ApplicationController
  before_action :authenticate_user!
  helper ProxyOrdersHelper

  def index
    @trades = Trade.where(user: current_user, status: [ :completed, :cancelled ])
                   .order(Arel.sql("COALESCE(trades.completed_at, trades.updated_at) DESC"))
                   .includes(:event, :user)
                   .page(params[:page])
                   .per(20)
  end

  def proxy_orders
    @proxy_orders = ProxyOrder.completed
                              .joins(:event, :proxy_order_participants)
                              .where(events: { discarded_at: nil })
                              .where(proxy_order_participants: { user_id: current_user.id })
                              .preload(:event,
                                       :proxy_order_participants,
                                       proxy_order_items: [ :proxy_order_price_lines, :proxy_order_allocations ])
                              .order("events.event_date DESC, proxy_orders.id DESC")
                              .page(params[:page])
                              .per(20)

    @my_payments = @proxy_orders.each_with_object({}) do |proxy_order, payments|
      me = proxy_order.proxy_order_participants.find { |p| p.user_id == current_user.id }
      payments[proxy_order.id] = ProxyOrderCalculator.new(proxy_order).payment_jpy(me) if me
    end
  end
end
