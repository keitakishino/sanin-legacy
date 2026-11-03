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
    @proxy_order = @event.proxy_order || restore_discarded_proxy_order || create_proxy_order_for_event
  end

  # イベントは生きているのに通販だけ論理削除されている不整合を直してから進む。
  # proxy_orders には default_scope（discarded_at: nil）があるため、この状態だと
  # @event.proxy_order は nil になり、作り直そうとすると event_id の一意制約に当たる。
  # 以前はそれを rescue しても nil のままで、@proxy_order.reload が NoMethodError になり
  # この画面が永久に 500 になっていた（自己修復しない）。
  def restore_discarded_proxy_order
    discarded = ProxyOrder.only_discarded.find_by(event_id: @event.id)
    return nil if discarded.nil?

    discarded.restore!
    record_audit("proxy_order.restore", target: discarded, details: { reason: "event_alive_but_proxy_order_discarded" })
    @event.reload.proxy_order
  end

  def create_proxy_order_for_event
    @event.create_proxy_order!
  rescue ActiveRecord::RecordNotUnique
    # 同時に開かれて先に作られた場合
    @event.reload
    @event.proxy_order || restore_discarded_proxy_order
  end

  def load_editor_state(open_item_ids: [])
    @proxy_order.reload
    @items = @proxy_order.proxy_order_items.includes(:expansion, :proxy_order_price_lines, proxy_order_allocations: { proxy_order_participant: :user }).order(:id)
    @participants = @proxy_order.proxy_order_participants.includes(:user, :proxy_order_allocations).order(:id)
    @calculator = ProxyOrderCalculator.new(@proxy_order)
    @users = User.order(:username)
    @participant_candidates = helpers.participant_candidates(@users, @participants)
    @participant_name_conflicts = helpers.participant_name_conflicts(@users, @participants)
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
