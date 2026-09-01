require "rails_helper"

RSpec.describe "Admin::TradeSpreadsheetExports", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }
  let(:event) { create(:event, spreadsheet_id: 'test-spreadsheet-id') }
  let(:trade) { create(:trade, event: event, user: general_user) }

  let(:mock_credentials) do
    {
      type: 'service_account',
      project_id: 'test-project',
      private_key_id: 'test-key-id',
      private_key: OpenSSL::PKey::RSA.new(2048).to_pem,
      client_email: 'test@test-project.iam.gserviceaccount.com',
      client_id: '1234567890',
      auth_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_uri: 'https://oauth2.googleapis.com/token',
      auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
      client_x509_cert_url: 'https://www.googleapis.com/certificates'
    }
  end

  before do
    allow(Rails.application.credentials).to receive(:google_sheets).and_return(mock_credentials)
  end

  def setup_google_api_mocks(sheets_service, tabs: nil, create_spreadsheet: false, add_sheet: true)
    # Mock create_spreadsheet if needed
    if create_spreadsheet
      spreadsheet_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
      allow(spreadsheet_result).to receive(:spreadsheet_id).and_return('new-spreadsheet-id')
      allow(sheets_service).to receive(:create_spreadsheet).and_return(spreadsheet_result)
    end

    # Mock get_spreadsheet for tabs
    if tabs.nil?
      # Default: existing tab with general_user.username
      sheet_properties = instance_double(Google::Apis::SheetsV4::SheetProperties)
      allow(sheet_properties).to receive(:title).and_return(general_user.username)
      allow(sheet_properties).to receive(:sheet_id).and_return(0)

      sheet = instance_double(Google::Apis::SheetsV4::Sheet)
      allow(sheet).to receive(:properties).and_return(sheet_properties)

      tabs = [ sheet ]
    end

    spreadsheet_get_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
    allow(spreadsheet_get_result).to receive(:sheets).and_return(tabs)
    allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet_get_result)

    # Mock batch_update_spreadsheet for add_sheet
    if add_sheet
      add_sheet_result = instance_double(Google::Apis::SheetsV4::AddSheetResponse)
      sheet_props = instance_double(Google::Apis::SheetsV4::SheetProperties)
      allow(sheet_props).to receive(:sheet_id).and_return(123)
      allow(add_sheet_result).to receive(:properties).and_return(sheet_props)

      response = instance_double(Google::Apis::SheetsV4::Response)
      allow(response).to receive(:add_sheet).and_return(add_sheet_result)

      batch_update_result = instance_double(Google::Apis::SheetsV4::BatchUpdateSpreadsheetResponse)
      allow(batch_update_result).to receive(:replies).and_return([ response ])
      allow(sheets_service).to receive(:batch_update_spreadsheet).and_return(batch_update_result)
    end

    # Mock clear_values and batch_update_values
    allow(sheets_service).to receive(:clear_values)
    batch_update_values_result = instance_double(Google::Apis::SheetsV4::BatchUpdateValuesResponse)
    allow(batch_update_values_result).to receive(:responses).and_return([])
    allow(sheets_service).to receive(:batch_update_values).and_return(batch_update_values_result)
  end

  def turbo_stream_headers
    { "Accept" => "text/vnd.turbo-stream.html" }
  end

  describe "POST /admin/events/:event_id/trades/:user_id/spreadsheet_export" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "does not update trade spreadsheet metadata" do
        expect {
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
        }.not_to change { trade.reload.spreadsheet_exported_at }
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        # Mock Google Sheets API
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service)
      end

      context "with valid trade" do
        it "returns turbo_stream response" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response).to have_http_status(:success)
          expect(response.media_type).to include("text/vnd.turbo-stream")
        end

        it "updates spreadsheet_exported_at" do
          before_time = Time.current
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          after_time = Time.current

          trade.reload
          expect(trade.spreadsheet_exported_at).to be_between(before_time, after_time)
        end

        it "updates spreadsheet_exported_by_id to current admin" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers

          trade.reload
          expect(trade.spreadsheet_exported_by_id).to eq(admin_user.id)
        end

        it "sets spreadsheet_tab_name to user username" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers

          trade.reload
          expect(trade.spreadsheet_tab_name).to eq(general_user.username)
        end

        it "displays success message in response" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response.body).to include("スプレッドシートに書き込みました")
        end
      end

      context "when trade does not exist" do
        it "returns not found status" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: 99999),
               headers: turbo_stream_headers
          expect(response).to have_http_status(:not_found)
        end
      end

      context "IDOR: accessing trade from different event" do
        let(:other_event) { create(:event, spreadsheet_id: 'other-spreadsheet-id') }
        let(:other_user) { create(:user, email: "other@example.com", password: "password123") }
        let(:other_trade) { create(:trade, event: other_event, user: other_user) }

        it "returns not found status" do
          # Trying to access other_event's trade via event's endpoint
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: other_user.id),
               headers: turbo_stream_headers
          expect(response).to have_http_status(:not_found)
        end

        it "does not update other trade's metadata" do
          expect {
            post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: other_user.id),
                 headers: turbo_stream_headers
          }.not_to change { other_trade.reload.spreadsheet_exported_at }
        end
      end

      context "when Google API error occurs" do
        before do
          sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
          allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

          error = Google::Apis::ClientError.new("Some Google API error")
          allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)
        end

        it "returns turbo_stream error response" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response).to have_http_status(:success)
          expect(response.media_type).to include("text/vnd.turbo-stream")
        end

        it "displays error message in response" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response.body).to include("エラーが発生しました")
        end

        it "does not update spreadsheet metadata" do
          expect {
            post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
                 headers: turbo_stream_headers
          }.not_to change { trade.reload.spreadsheet_exported_at }
        end
      end

      context "when rate limit error occurs" do
        before do
          sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
          allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

          error = Google::Apis::ClientError.new("rateLimitExceeded")
          allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)
        end

        it "displays rate limit message" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response.body).to include("レート制限")
        end
      end

      context "when spreadsheet not found error occurs" do
        before do
          sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
          allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

          error = Google::Apis::ClientError.new("notFound")
          allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)
        end

        it "clears spreadsheet_id from event" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(event.reload.spreadsheet_id).to be_nil
        end

        it "displays appropriate error message" do
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
          expect(response.body).to include("見つかりません")
        end
      end
    end

    context "when trade has multiple card offers and wants" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        # Create multiple cards
        create_list(:trade_card_offer, 3, trade: trade)
        create_list(:trade_card_want, 2, trade: trade)
        trade.recalculate_totals!

        # Mock Google Sheets API
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service)
      end

      it "successfully exports all card data" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(response.body).to include("スプレッドシートに書き込みました")
      end
    end

    context "when spreadsheet_id is not set on event (new file creation)" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        event.update!(spreadsheet_id: nil)

        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service, tabs: [], create_spreadsheet: true, add_sheet: true)
      end

      it "creates new spreadsheet and saves spreadsheet_id to event" do
        expect {
          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers
        }.to change { event.reload.spreadsheet_id }.from(nil).to('new-spreadsheet-id')
      end

      it "creates new tab when it does not exist" do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service, tabs: [], create_spreadsheet: true, add_sheet: true)

        expect(sheets_service).to receive(:batch_update_spreadsheet).at_least(:once)

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
      end

      it "returns success response" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(response.body).to include("スプレッドシートに書き込みました")
      end
    end

    context "when tab does not exist (new tab creation)" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "creates new tab with user username" do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        # Tabs list is empty (no matching tab exists)
        setup_google_api_mocks(sheets_service, tabs: [], add_sheet: true)

        expect(sheets_service).to receive(:batch_update_spreadsheet).at_least(:once)

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(response.body).to include("スプレッドシートに書き込みました")
      end

      it "updates trade with new tab name" do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service, tabs: [], add_sheet: true)

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        trade.reload
        expect(trade.spreadsheet_tab_name).to eq(general_user.username)
      end
    end

    context "when spreadsheet and tab already exist (reusing existing resources)" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        event.update!(spreadsheet_id: 'existing-spreadsheet-id')

        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        # Tab exists with general_user.username
        setup_google_api_mocks(sheets_service, add_sheet: false)
      end

      it "reuses existing spreadsheet without creating new one" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        expect(event.reload.spreadsheet_id).to eq('existing-spreadsheet-id')
      end

      it "reuses existing tab without creating new sheet" do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service, add_sheet: false)

        expect(sheets_service).not_to receive(:batch_update_spreadsheet)

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
      end

      it "updates trade metadata with same event spreadsheet_id" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        trade.reload
        expect(trade.spreadsheet_tab_name).to eq(general_user.username)
        expect(trade.spreadsheet_exported_at).to be_present
      end
    end

    context "when re-exporting trade data (overwrite scenario)" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        # Create multiple cards
        create_list(:trade_card_offer, 2, trade: trade)
        create_list(:trade_card_want, 2, trade: trade)
        trade.recalculate_totals!

        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service, add_sheet: false)
      end

      it "updates spreadsheet_exported_at to new timestamp" do
        travel_to Time.zone.local(2025, 6, 15, 14, 0, 0) do
          # Set previous export metadata
          trade.update!(
            spreadsheet_exported_at: Time.zone.local(2025, 6, 14, 14, 0, 0),
            spreadsheet_tab_name: general_user.username,
            spreadsheet_exported_by_id: admin_user.id
          )

          previous_time = trade.spreadsheet_exported_at

          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers

          trade.reload
          expect(trade.spreadsheet_exported_at).to be > previous_time
        end
      end

      it "preserves spreadsheet_tab_name on re-export" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        trade.reload
        expect(trade.spreadsheet_tab_name).to eq(general_user.username)
      end

      it "updates spreadsheet_exported_by_id to current user" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        trade.reload
        expect(trade.spreadsheet_exported_by_id).to eq(admin_user.id)
      end
    end

    context "with different trade statuses" do
      shared_examples "allows export regardless of status" do
        it "allows export for #{described_class}" do
          post signin_path, params: { email: admin_user.email, password: "password123" }

          sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
          allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
          setup_google_api_mocks(sheets_service)

          post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
               headers: turbo_stream_headers

          expect(response).to have_http_status(:success)
          expect(trade.reload.spreadsheet_exported_at).to be_present
        end
      end

      context "when trade status is pending" do
        before { trade.update!(status: :pending) }

        it_behaves_like "allows export regardless of status"
      end

      context "when trade status is in_progress" do
        before { trade.update!(status: :in_progress) }

        it_behaves_like "allows export regardless of status"
      end

      context "when trade status is completed" do
        before { trade.update!(status: :completed) }

        it_behaves_like "allows export regardless of status"
      end
    end

    context "tab naming" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }

        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)
        setup_google_api_mocks(sheets_service)
      end

      it "uses user.username as tab name exactly" do
        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers
        trade.reload
        expect(trade.spreadsheet_tab_name).to eq(general_user.username)
      end

      it "sanitizes special characters in username" do
        general_user.update!(username: "user/with\\special?chars[test]")

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers

        trade.reload
        # Expect special characters to be replaced with underscore
        expect(trade.spreadsheet_tab_name).to eq("user_with_special_chars_test_")
      end

      it "uses full username when within 100 character limit" do
        # Note: User.username has a maximum length of 50 characters due to validation,
        # so the sanitize_tab_name truncation to 100 characters is not testable via
        # username alone. However, GoogleSheetWriter.sanitize_tab_name does support
        # truncation to 100 characters for internal use.
        medium_username = "a" * 50
        general_user.update!(username: medium_username)

        post admin_event_trade_spreadsheet_export_path(event_id: event.id, user_id: trade.user_id),
             headers: turbo_stream_headers

        trade.reload
        expect(trade.spreadsheet_tab_name).to eq(medium_username)
      end
    end
  end
end
