class Admin::ProxyOrdersController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  def show
    load_editor_state(open_item_ids: [])
  end

  def update
    status = params.dig(:proxy_order, :status)

    if status.present?
      handle_status_transition(status)
      return
    end

    if !@proxy_order.fees_editable?
      reject_locked_operation(:fees)
      return
    end

    params_to_update = params.require(:proxy_order).permit(:tax_usd, :customs_usd, :shipping_usd, :payment_fee_usd, :usd_jpy_rate)
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

  private

  def handle_status_transition(new_status)
    from_status = @proxy_order.status

    if @proxy_order.transition_to(new_status)
      record_audit("proxy_order.status_change", target: @proxy_order, details: { from: from_status, to: new_status })
      redirect_to admin_event_proxy_order_path(@event), notice: t(".status_changed", status: t("activerecord.enums.proxy_order.status.#{new_status}")), status: :see_other
    else
      @transition_errors = @proxy_order.errors.full_messages
      record_audit("proxy_order.status_change", target: @proxy_order, result: :failure, details: { from: from_status, to: new_status, reason: @transition_errors.join(", ") })
      load_editor_state

      respond_to do |format|
        format.turbo_stream { render "admin/proxy_orders/transition_error", status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end
end
