class Admin::ProxyOrderPriceLinesController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  before_action :set_item

  def create
    @line = @item.proxy_order_price_lines.build(price_line_params)

    if @line.save
      record_audit("proxy_order_price_line.create", target: @line)
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
    @line = @item.proxy_order_price_lines.find(params[:id])

    if @line.update(price_line_params)
      record_audit("proxy_order_price_line.update", target: @line, details: @line.saved_changes.except("updated_at"))
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
    @line = @item.proxy_order_price_lines.find(params[:id])
    @line.destroy

    record_audit("proxy_order_price_line.destroy", target: @line)
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

  def price_line_params
    params.require(:proxy_order_price_line).permit(:unit_price_usd, :quantity)
  end
end
