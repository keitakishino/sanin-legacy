require "google/apis/sheets_v4"
require "google/apis/drive_v3"
require "googleauth"
require "stringio"

# Google Sheets API 初期化設定（Rails credentials からサービスアカウント認証情報を読み込む）
module GoogleSheetsConfig
  SCOPES = [
    Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
    Google::Apis::DriveV3::AUTH_DRIVE
  ].freeze

  class CredentialsNotConfiguredError < StandardError; end

  class << self
    def sheets_client
      client = Google::Apis::SheetsV4::SheetsService.new
      client.authorization = authorizer
      client
    end

    def drive_client
      client = Google::Apis::DriveV3::DriveService.new
      client.authorization = authorizer
      client
    end

    private

    def authorizer
      credentials = google_sheets_credentials
      raise CredentialsNotConfiguredError, "Rails credentials に google_sheets 設定がありません" if credentials.blank?

      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(credentials.to_json),
        scope: SCOPES
      )
    end

    def google_sheets_credentials
      Rails.application.credentials.google_sheets
    end
  end
end
