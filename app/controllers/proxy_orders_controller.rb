class ProxyOrdersController < ApplicationController
  before_action :authenticate_user!
  helper ProxyOrdersHelper

  def show
    @event = Event.find(params[:event_id])
    raise ActiveRecord::RecordNotFound unless @event.proxy_order?

    @proxy_order = @event.proxy_order
    raise ActiveRecord::RecordNotFound unless @proxy_order.present?

    @participant = @proxy_order.proxy_order_participants.find_by(user_id: current_user.id)
    raise ActiveRecord::RecordNotFound unless @participant.present?

    @allocations = @participant.proxy_order_allocations
                               .joins(:proxy_order_item)
                               .merge(ProxyOrderItem.all)
                               .includes(proxy_order_item: [ :expansion, :proxy_order_price_lines ])
                               .order("proxy_order_items.id")

    @calculator = ProxyOrderCalculator.new(@proxy_order)
  end
end
