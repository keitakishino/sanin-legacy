class Admin::ProxyOrderPriceLinesController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  before_action :set_item

  def create
    unless @proxy_order.details_editable?
      reject_locked_operation(@proxy_order.completed? ? :completed : :details)
      return
    end

    @line = @item.proxy_order_price_lines.build(price_line_params)

    if @line.save
      record_audit("proxy_order_price_line.create", target: @line)
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        format.turbo_stream { render "admin/proxy_orders/item_changed", locals: { toast_message: t(".created"), focus_id: helpers.dom_id(@item, :new_price_line_unit_price) } }
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
    submitted = params.require(:proxy_order_price_line).keys.map(&:to_s)

    if @proxy_order.completed?
      reject_locked_operation(:completed)
      return
    end

    if @proxy_order.ordered?
      if submitted.include?("lost_quantity")
        reject_locked_operation(:arrival_inputs)
        return
      end
      params_to_update = price_line_params
    elsif @proxy_order.arrived?
      if (submitted - %w[lost_quantity]).any?
        reject_locked_operation(:details)
        return
      end
      lost = params[:proxy_order_price_line][:lost_quantity]
      lost = lost.blank? ? 0 : lost.to_i
      params_to_update = { lost_quantity: lost }
    end

    if @line.update(params_to_update)
      if @proxy_order.arrived? && submitted.include?("lost_quantity")
        record_audit("proxy_order_price_line.update_lost", target: @line, details: @line.saved_changes.except("updated_at"))
      else
        record_audit("proxy_order_price_line.update", target: @line, details: @line.saved_changes.except("updated_at"))
      end
      load_editor_state(open_item_ids: [ @item.id ])

      respond_to do |format|
        locals = { toast_message: t(".updated") }
        locals[:focus_id] = next_focus_id if params[:focus_next].present?
        format.turbo_stream { render "admin/proxy_orders/item_changed", locals: }
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
    unless @proxy_order.details_editable?
      reject_locked_operation(@proxy_order.completed? ? :completed : :details)
      return
    end

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

  def next_focus_id
    lines = @item.proxy_order_price_lines.to_a
    index = lines.index { |l| l.id == @line.id }
    next_line = lines[index + 1]
    next_line.present? ? helpers.dom_id(next_line, :unit_price) : helpers.dom_id(@item, :new_price_line_unit_price)
  end
end
