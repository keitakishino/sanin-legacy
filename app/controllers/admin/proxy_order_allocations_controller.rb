class Admin::ProxyOrderAllocationsController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  before_action :set_item

  def create
    @allocation = @item.proxy_order_allocations.build(allocation_params)

    if @allocation.save
      record_audit("proxy_order_allocation.create", target: @allocation)
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        format.turbo_stream { render "admin/proxy_orders/item_changed", locals: { toast_message: t(".created") } }
        format.html { redirect_to admin_event_proxy_order_path(@event) }
      end
    else
      load_editor_state(open_item_ids: [ @item.id ])
      respond_to do |format|
        format.turbo_stream { render :create_error, status: :unprocessable_entity }
        format.html { render "admin/proxy_orders/show", status: :unprocessable_entity }
      end
    end
  end

  def update
    @allocation = @item.proxy_order_allocations.find(params[:id])

    if @allocation.update(allocation_params)
      record_audit("proxy_order_allocation.update", target: @allocation, details: @allocation.saved_changes.except("updated_at"))
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        format.turbo_stream { render "admin/proxy_orders/item_changed", locals: { toast_message: t(".updated") } }
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
    @allocation = @item.proxy_order_allocations.find(params[:id])
    @allocation.destroy

    record_audit("proxy_order_allocation.destroy", target: @allocation)
    load_editor_state(open_item_ids: [ @item.id ])

    respond_to do |format|
      format.turbo_stream { render "admin/proxy_orders/item_changed", locals: { toast_message: t(".deleted") } }
      format.html { redirect_to admin_event_proxy_order_path(@event) }
    end
  end

  private

  def set_item
    @item = @proxy_order.proxy_order_items.find(params[:item_id])
  end

  def allocation_params
    params.require(:proxy_order_allocation).permit(:proxy_order_participant_id, :quantity)
  end
end
