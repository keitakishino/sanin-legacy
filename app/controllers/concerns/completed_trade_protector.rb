module CompletedTradeProtector
  extend ActiveSupport::Concern

  private

  def check_card_detail_operation_permitted
    reason = @trade&.card_detail_denial_reason(current_user, action_name)
    return if reason.nil?

    message = case reason
    when :completed
      "完了状態のトレード内容は変更できません"
    when :in_progress
      "進行中のトレードのカード明細は編集・削除できません"
    end

    if request.format.symbol == :turbo_stream
      template = "trade_#{reason}_error"
      render template, status: :unprocessable_entity
    else
      redirect_to trade_path(@trade.event), alert: message
    end
  end
end
