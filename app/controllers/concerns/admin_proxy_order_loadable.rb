module AdminProxyOrderLoadable
  extend ActiveSupport::Concern

  included do
    before_action :set_event
    before_action :set_proxy_order
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
    raise ActiveRecord::RecordNotFound unless @event.proxy_order?
  end

  def set_proxy_order
    @proxy_order = @event.proxy_order || @event.create_proxy_order!
  rescue ActiveRecord::RecordNotUnique
    @event.reload
    @proxy_order = @event.proxy_order
  end

  def load_editor_state(open_item_ids: [])
    @proxy_order.reload
    @items = @proxy_order.proxy_order_items.includes(:expansion, :proxy_order_price_lines, proxy_order_allocations: { proxy_order_participant: :user }).order(:id)
    @participants = @proxy_order.proxy_order_participants.includes(:user).order(:id)
    @calculator = ProxyOrderCalculator.new(@proxy_order)
    @users = User.order(:username)
    @open_item_ids = open_item_ids
  end
end
