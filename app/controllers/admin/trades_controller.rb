class Admin::TradesController < Admin::BaseController
  include CardDetailListAssignment

  before_action :set_event
  before_action :set_trade, only: [ :show, :update ]
  before_action :assign_card_detail_lists, only: [ :show, :update ]

  def show
  end

  def update
    status_param = trade_params[:status]

    # Validate status value
    if status_param.present? && !Trade.statuses.keys.include?(status_param)
      @trade.errors.add(:status, "は無効な値です")
      record_audit("trade.update", target: @trade, result: :failure, details: audit_failure_details(@trade))
      render :show, status: :unprocessable_entity
      return
    end

    # Handle completed status
    if status_param == "completed"
      @trade.completed_by = current_user
      @trade.completed_at = Time.current
    end

    if @trade.update(trade_params)
      record_audit("trade.update", target: @trade, details: @trade.saved_changes.except("updated_at"))
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_event_trade_path(@event, @trade), notice: "トレード情報を更新しました" }
      end
    else
      record_audit("trade.update", target: @trade, result: :failure, details: audit_failure_details(@trade))
      respond_to do |format|
        format.turbo_stream { render :show, status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_trade
    @trade = @event.trades.find(params[:id])
  end

  def trade_params
    params.require(:trade).permit(:status, :cancelled_reason)
  end
end
