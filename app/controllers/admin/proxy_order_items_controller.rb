class Admin::ProxyOrderItemsController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  before_action :check_details_editable, only: [ :create, :update, :destroy ]

  def create
    @item = @proxy_order.proxy_order_items.build(item_params)

    if @item.save
      record_audit("proxy_order_item.create", target: @item)
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_event_proxy_order_path(@event) }
      end
    else
      load_editor_state
      respond_to do |format|
        format.turbo_stream { render :create_error, status: :unprocessable_entity }
        format.html { render "admin/proxy_orders/show", status: :unprocessable_entity }
      end
    end
  end

  def update
    @item = @proxy_order.proxy_order_items.find(params[:id])

    if @item.update(item_params)
      record_audit("proxy_order_item.update", target: @item, details: @item.saved_changes.except("updated_at"))
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_event_proxy_order_path(@event) }
      end
    else
      load_editor_state(open_item_ids: [ @item.id ])
      respond_to do |format|
        format.turbo_stream { render :update_error, status: :unprocessable_entity }
        format.html { render "admin/proxy_orders/show", status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @item = @proxy_order.proxy_order_items.find(params[:id])
    @item.update!(discarded_at: Time.current)

    record_audit("proxy_order_item.discard", target: @item)
    load_editor_state

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_event_proxy_order_path(@event) }
    end
  end

  private

  def item_params
    params.require(:proxy_order_item).permit(:card_name, :expansion_id, :foil, :frame)
  end

  def check_details_editable
    unless @proxy_order.details_editable?
      reject_locked_operation(@proxy_order.completed? ? :completed : :details)
    end
  end
end
