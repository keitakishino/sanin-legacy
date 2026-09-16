module CompletedTradeProtector
  extend ActiveSupport::Concern

  private

  def check_trade_not_completed
    return if !@trade&.completed?

    if request.format.symbol == :turbo_stream
      render :trade_completed_error, status: :unprocessable_entity
    else
      redirect_to trade_path(@trade.event), alert: "完了状態のトレード内容は変更できません"
    end
  end
end
