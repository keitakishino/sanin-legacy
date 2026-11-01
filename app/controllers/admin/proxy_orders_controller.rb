class Admin::ProxyOrdersController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  def show
    load_editor_state(open_item_ids: [])
  end

  def update
    params_to_update = params.require(:proxy_order).permit(:tax_usd, :customs_usd, :shipping_usd, :usd_jpy_rate)
    params_to_update[:usd_jpy_rate] = nil if params_to_update[:usd_jpy_rate].blank?

    if @proxy_order.update(params_to_update)
      record_audit("proxy_order.update", target: @proxy_order, details: @proxy_order.saved_changes.except("updated_at"))
      load_editor_state

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_event_proxy_order_path(@event) }
      end
    else
      load_editor_state
      respond_to do |format|
        format.turbo_stream { render :update_error, status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end
end
