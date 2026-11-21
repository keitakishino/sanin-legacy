class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def show
    # 参加者の絞り込みはサブクエリで行う。joins + where で絞ると includes が JOIN 側に切り替わり、
    # proxy_order_participants が自分 1 人分だけになって送料の割り勘人数が狂う。
    my_order_ids = ProxyOrderParticipant.where(user_id: current_user.id).select(:proxy_order_id)
    @my_proxy_orders = ProxyOrder.joins(:event)
                                  .where(id: my_order_ids)
                                  .where(events: { discarded_at: nil })
                                  .includes(:event, proxy_order_participants: :user)
                                  .order("events.event_date DESC")

    # ダッシュボードのカードに自分の支払い金額を出す（設計書「5a ユーザー ダッシュボード」）
    @my_proxy_order_payments = @my_proxy_orders.each_with_object({}) do |proxy_order, acc|
      participant = proxy_order.proxy_order_participants.find { |p| p.user_id == current_user.id }
      acc[proxy_order.id] = ProxyOrderCalculator.new(proxy_order).payment_jpy(participant) if participant
    end
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
