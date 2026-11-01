class Admin::ProxyOrderParticipantsController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  def create
    unless @proxy_order.details_editable?
      reject_locked_operation(@proxy_order.completed? ? :completed : :details)
      return
    end

    @participant = @proxy_order.proxy_order_participants.build(participant_params)

    if @participant.save
      record_audit("proxy_order_participant.create", target: @participant)
      load_editor_state

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
    @participant = @proxy_order.proxy_order_participants.find(params[:id])
    submitted = params.require(:proxy_order_participant).keys.map(&:to_s)

    if @proxy_order.completed?
      reject_locked_operation(:completed)
      return
    end

    if @proxy_order.ordered?
      if submitted.include?("handed_over_at")
        reject_locked_operation(:arrival_inputs)
        return
      end
      params_to_update = participant_params
    elsif @proxy_order.arrived?
      if (submitted - %w[handed_over_at]).any?
        reject_locked_operation(:details)
        return
      end
      checked = ActiveModel::Type::Boolean.new.cast(params[:proxy_order_participant][:handed_over_at])
      params_to_update = { handed_over_at: checked ? (@participant.handed_over_at || Time.current) : nil }
    end

    if @participant.update(params_to_update)
      if @proxy_order.arrived? && submitted.include?("handed_over_at")
        record_audit("proxy_order_participant.hand_over", target: @participant, details: @participant.saved_changes.except("updated_at"))
      else
        record_audit("proxy_order_participant.update", target: @participant, details: @participant.saved_changes.except("updated_at"))
      end
      load_editor_state

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_event_proxy_order_path(@event) }
      end
    else
      load_editor_state
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

    @participant = @proxy_order.proxy_order_participants.find(params[:id])
    @participant.destroy

    record_audit("proxy_order_participant.destroy", target: @participant)
    load_editor_state

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_event_proxy_order_path(@event) }
    end
  end

  private

  def participant_params
    params.require(:proxy_order_participant).permit(:user_id, :guest_name).tap do |p|
      p[:user_id] = nil if p[:user_id].blank?
      p[:guest_name] = nil if p[:guest_name].blank?
    end
  end
end
