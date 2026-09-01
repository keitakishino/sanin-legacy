class Admin::TradeSpreadsheetExportsController < Admin::BaseController
  before_action :set_event
  before_action :set_trade

  def create
    result = GoogleSheetWriter.new(@event, @trade, current_user).call

    respond_to do |format|
      format.turbo_stream do
        @success = true
        @message = result[:message]
      end
    end
  rescue GoogleSheetWriter::SpreadsheetError => e
    handle_spreadsheet_error(e)
  rescue GoogleSheetWriter::RateLimitError => e
    handle_rate_limit_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_trade
    @trade = @event.trades.find_by(user_id: params[:user_id])
    raise ActiveRecord::RecordNotFound unless @trade
  end

  def handle_spreadsheet_error(error)
    respond_to do |format|
      format.turbo_stream do
        @success = false
        @message = error.message
        render :error
      end
    end
  end

  def handle_rate_limit_error(error)
    respond_to do |format|
      format.turbo_stream do
        @success = false
        @message = error.message
        render :error
      end
    end
  end

  def handle_unexpected_error(error)
    Rails.logger.error("Unexpected error in spreadsheet export: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))

    respond_to do |format|
      format.turbo_stream do
        @success = false
        @message = "予期しないエラーが発生しました。サポートチームにお問い合わせください。"
        render :error
      end
    end
  end
end
