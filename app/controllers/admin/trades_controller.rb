class Admin::TradesController < Admin::BaseController
  before_action :set_event
  before_action :set_trade, only: [ :show, :update ]

  def show
  end

  def update
    status_param = trade_params[:status]

    # Validate status value
    if status_param.present? && !Trade.statuses.keys.include?(status_param)
      @trade.errors.add(:status, "は無効な値です")
      render :show, status: :unprocessable_entity
      return
    end

    # Handle completed status
    if status_param == "completed"
      @trade.completed_by = current_user
      @trade.completed_at = Time.current
    end

    if @trade.update(trade_params)
      redirect_to admin_event_trade_path(@event, @trade), notice: "トレード情報を更新しました"
    else
      render :show, status: :unprocessable_entity
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
