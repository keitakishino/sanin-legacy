class Admin::ProxyOrderParticipantsController < Admin::BaseController
  include AdminProxyOrderLoadable
  helper ProxyOrdersHelper

  def create
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

    if @participant.update(participant_params)
      record_audit("proxy_order_participant.update", target: @participant, details: @participant.saved_changes.except("updated_at"))
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
