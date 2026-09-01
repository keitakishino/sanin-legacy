require "google/apis/sheets_v4"
require "google/apis/drive_v3"

# Service for writing trade data to Google Sheets
# Handles spreadsheet creation, tab management, and data writing
class GoogleSheetWriter
  class SpreadsheetError < StandardError; end
  class RateLimitError < StandardError; end

  def initialize(event, trade, current_user)
    @event = event
    @trade = trade
    @current_user = current_user
    @sheets_service = GoogleSheetsConfig.sheets_client
    @drive_service = GoogleSheetsConfig.drive_client
  rescue GoogleSheetsConfig::CredentialsNotConfiguredError => e
    raise SpreadsheetError, e.message
  end

  def call
    ensure_spreadsheet_exists
    ensure_tab_exists
    write_trade_data
    update_trade_metadata
    { success: true, message: "スプレッドシートに書き込みました" }
  rescue GoogleSheetsConfig::CredentialsNotConfiguredError => e
    Rails.logger.error("Google credentials not configured: #{e.message}")
    raise SpreadsheetError, "Google Sheets認証情報が設定されていません"
  rescue Google::Apis::Error => e
    handle_google_api_error(e)
  end

  private

  def ensure_spreadsheet_exists
    if @event.spreadsheet_id.blank?
      create_spreadsheet
    end
  end

  def create_spreadsheet
    title = "#{@event.title} - トレード記録"
    spreadsheet = Google::Apis::SheetsV4::Spreadsheet.new(
      properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(title: title)
    )

    result = @sheets_service.create_spreadsheet(spreadsheet)
    spreadsheet_id = result.spreadsheet_id

    @event.update!(spreadsheet_id: spreadsheet_id)
    Rails.logger.info("Created new spreadsheet: #{spreadsheet_id} for event #{@event.id}")
  end

  def ensure_tab_exists
    tabs = fetch_sheet_tabs
    tab_name = sanitize_tab_name(@trade.user.username)

    existing_tab = tabs.find { |tab| tab.properties.title == tab_name }

    if existing_tab.present?
      @tab_id = existing_tab.properties.sheet_id
      clear_tab_content
    else
      create_tab(tab_name)
    end
  end

  def fetch_sheet_tabs
    result = @sheets_service.get_spreadsheet(@event.spreadsheet_id)
    result.sheets || []
  end

  def sanitize_tab_name(name)
    # Remove special characters that Google Sheets doesn't allow
    sanitized = name.gsub(%r{[/\\?*\[\]]}, "_")
    # Limit to 100 characters
    sanitized[0..99]
  end

  def create_tab(tab_name)
    request = Google::Apis::SheetsV4::AddSheetRequest.new(
      properties: Google::Apis::SheetsV4::SheetProperties.new(title: tab_name)
    )
    batch_update_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
      requests: [ Google::Apis::SheetsV4::Request.new(add_sheet: request) ]
    )

    result = @sheets_service.batch_update_spreadsheet(@event.spreadsheet_id, batch_update_request)
    @tab_id = result.replies.first.add_sheet.properties.sheet_id
    Rails.logger.info("Created new tab '#{tab_name}' in spreadsheet #{@event.spreadsheet_id}")
  end

  def clear_tab_content
    # Clear existing content by updating with empty values
    range = "#{tab_name}!A:Z"
    @sheets_service.clear_values(@event.spreadsheet_id, range)
  end

  def write_trade_data
    tab_name = sanitize_tab_name(@trade.user.username)
    range = "#{tab_name}!A1"

    rows = build_spreadsheet_rows
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: rows)

    request = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new(
      data: [ value_range ],
      value_input_option: "RAW"
    )

    @sheets_service.batch_update_values(@event.spreadsheet_id, request)

    Rails.logger.info("Wrote trade data for user #{@trade.user.id} to spreadsheet #{@event.spreadsheet_id}")
  end

  def build_spreadsheet_rows
    rows = []

    # Header row
    rows << [ "カード名", "枚数", "言語", "状態", "特殊", "枠", "PW", "金額" ]

    # Offers (出すカード)
    rows << [ "", "", "", "", "", "", "", "" ]  # Blank row for separation
    rows << [ "【 出すカード 】" ]

    @trade.trade_card_offers.each do |offer|
      rows << [
        offer.card_name,
        offer.quantity.to_s,
        offer.language,
        I18n.t("activerecord.enums.trade_card_offer.condition.#{offer.condition}", default: offer.condition),
        offer.foil,
        offer.frame,
        offer.pw_mark? ? "○" : "",
        offer.amount.to_s
      ]
    end

    # Wants (欲しいカード)
    rows << [ "", "", "", "", "", "", "", "" ]  # Blank row for separation
    rows << [ "【 欲しいカード 】" ]

    @trade.trade_card_wants.each do |want|
      rows << [
        want.card_name,
        want.quantity.to_s,
        want.language.present? ? want.language : "不問",
        want.conditions_to_display,
        want.foil.present? ? want.foil : "不問",
        want.frame.present? ? want.frame : "不問",
        "",
        want.amount.to_s
      ]
    end

    # Summary rows
    rows << [ "", "", "", "", "", "", "", "" ]  # Blank row
    rows << [ "合計" ]
    rows << [ "出すカード合計", "", "", "", "", "", "", @trade.offers_total_amount.to_s ]
    rows << [ "欲しいカード合計", "", "", "", "", "", "", @trade.wants_total_amount.to_s ]
    rows << [ "差額（出す - 欲しい）", "", "", "", "", "", "", @trade.net_amount.to_s ]

    rows
  end

  def tab_name
    sanitize_tab_name(@trade.user.username)
  end

  def update_trade_metadata
    @trade.update!(
      spreadsheet_exported_at: Time.current,
      spreadsheet_tab_name: tab_name,
      spreadsheet_exported_by_id: @current_user.id
    )

    Rails.logger.info("Updated trade #{@trade.id} spreadsheet metadata")
  end

  def handle_google_api_error(error)
    error_message = error.message

    case error_message
    when /quota.*exceeded|rateLimitExceeded/i
      Rails.logger.warn("Rate limit exceeded: #{error_message}")
      raise RateLimitError, "APIレート制限に達しました。しばらく待ってから再度お試しください"
    when /notFound|404/i
      Rails.logger.error("Spreadsheet not found: #{@event.spreadsheet_id}")
      @event.update(spreadsheet_id: nil)
      raise SpreadsheetError, "スプレッドシートが見つかりません。新規に作成してください"
    when /forbidden|403/i
      Rails.logger.error("Permission denied: #{error_message}")
      raise SpreadsheetError, "スプレッドシートへのアクセス権がありません"
    else
      Rails.logger.error("Google API error: #{error_message}")
      raise SpreadsheetError, "スプレッドシート書き込み中にエラーが発生しました: #{error_message}"
    end
  end
end
