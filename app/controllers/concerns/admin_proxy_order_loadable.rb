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
    @transition_errors = nil unless defined?(@transition_errors)
    # 保存に失敗した子（価格行・注文）が関連に残ったまま再描画すると、
    # id が nil のレコードで URL を組もうとして落ちる。DB から読み直した個体に差し替える
    @item = @items.find { |i| i.id == @item.id } || @item if @item&.persisted?
  end

  private

  def reject_locked_operation(message_key)
    load_editor_state
    @locked_message = t("admin.proxy_order.locked.#{message_key}")
    respond_to do |format|
      format.turbo_stream { render "admin/proxy_orders/locked", status: :unprocessable_entity }
      format.html do
        @proxy_order.reload
        render action: :show, controller: "admin/proxy_orders", status: :unprocessable_entity
      end
    end
  end
end
