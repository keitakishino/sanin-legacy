require "rails_helper"

RSpec.describe GoogleSheetWriter, type: :service do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:user) { create(:user, email: "user@example.com", password: "password123", username: "test_user") }
  let(:event) { create(:event, spreadsheet_id: nil) }
  let(:trade) { create(:trade, event: event, user: user) }

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

  describe '#call' do
    context 'when spreadsheet_id is nil' do
      it 'creates a new spreadsheet' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        # Mock create_spreadsheet
        spreadsheet_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
        allow(spreadsheet_result).to receive(:spreadsheet_id).and_return('test-spreadsheet-id')
        allow(sheets_service).to receive(:create_spreadsheet).and_return(spreadsheet_result)

        # Mock get_spreadsheet for tabs
        sheet_properties = instance_double(Google::Apis::SheetsV4::SheetProperties)
        allow(sheet_properties).to receive(:title).and_return(user.username)
        allow(sheet_properties).to receive(:sheet_id).and_return(0)

        sheet = instance_double(Google::Apis::SheetsV4::Sheet)
        allow(sheet).to receive(:properties).and_return(sheet_properties)

        spreadsheet_get_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
        allow(spreadsheet_get_result).to receive(:sheets).and_return([sheet])
        allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet_get_result)

        # Mock clear_values and batch_update_values
        allow(sheets_service).to receive(:clear_values)
        batch_update_result = instance_double(Google::Apis::SheetsV4::BatchUpdateValuesResponse)
        allow(batch_update_result).to receive(:responses).and_return([])
        allow(sheets_service).to receive(:batch_update_values).and_return(batch_update_result)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.call

        expect(event.reload.spreadsheet_id).to eq('test-spreadsheet-id')
        expect(result[:success]).to be true
      end
    end

    context 'when spreadsheet_id already exists' do
      let(:event) { create(:event, spreadsheet_id: 'existing-spreadsheet-id') }

      it 'uses existing spreadsheet' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        # Mock get_spreadsheet for tabs
        sheet_properties = instance_double(Google::Apis::SheetsV4::SheetProperties)
        allow(sheet_properties).to receive(:title).and_return(user.username)
        allow(sheet_properties).to receive(:sheet_id).and_return(0)

        sheet = instance_double(Google::Apis::SheetsV4::Sheet)
        allow(sheet).to receive(:properties).and_return(sheet_properties)

        spreadsheet_get_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
        allow(spreadsheet_get_result).to receive(:sheets).and_return([sheet])
        allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet_get_result)

        # Mock clear_values and batch_update_values
        allow(sheets_service).to receive(:clear_values)
        batch_update_result = instance_double(Google::Apis::SheetsV4::BatchUpdateValuesResponse)
        allow(batch_update_result).to receive(:responses).and_return([])
        allow(sheets_service).to receive(:batch_update_values).and_return(batch_update_result)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.call

        expect(event.spreadsheet_id).to eq('existing-spreadsheet-id')
        expect(result[:success]).to be true
      end
    end

    context 'when updating trade metadata' do
      let(:event) { create(:event, spreadsheet_id: 'existing-spreadsheet-id') }

      it 'updates spreadsheet_exported_at, spreadsheet_tab_name, and spreadsheet_exported_by_id' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        # Mock get_spreadsheet for tabs
        sheet_properties = instance_double(Google::Apis::SheetsV4::SheetProperties)
        allow(sheet_properties).to receive(:title).and_return(user.username)
        allow(sheet_properties).to receive(:sheet_id).and_return(0)

        sheet = instance_double(Google::Apis::SheetsV4::Sheet)
        allow(sheet).to receive(:properties).and_return(sheet_properties)

        spreadsheet_get_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
        allow(spreadsheet_get_result).to receive(:sheets).and_return([sheet])
        allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet_get_result)

        # Mock clear_values and batch_update_values
        allow(sheets_service).to receive(:clear_values)
        batch_update_result = instance_double(Google::Apis::SheetsV4::BatchUpdateValuesResponse)
        allow(batch_update_result).to receive(:responses).and_return([])
        allow(sheets_service).to receive(:batch_update_values).and_return(batch_update_result)

        before_time = Time.current
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        writer.call
        after_time = Time.current

        trade.reload
        expect(trade.spreadsheet_exported_at).to be_between(before_time, after_time)
        expect(trade.spreadsheet_tab_name).to eq(user.username)
        expect(trade.spreadsheet_exported_by_id).to eq(admin_user.id)
      end
    end

    context 'when sanitizing tab names with special characters' do
      let(:event) { create(:event, spreadsheet_id: 'existing-spreadsheet-id') }
      let(:user) { create(:user, username: 'user/with\\special[chars]') }
      let(:trade) { create(:trade, event: event, user: user) }

      it 'replaces special characters with underscores' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        # Mock get_spreadsheet for tabs
        sheet_properties = instance_double(Google::Apis::SheetsV4::SheetProperties)
        allow(sheet_properties).to receive(:title).and_return('user_with_special_chars_')
        allow(sheet_properties).to receive(:sheet_id).and_return(0)

        sheet = instance_double(Google::Apis::SheetsV4::Sheet)
        allow(sheet).to receive(:properties).and_return(sheet_properties)

        spreadsheet_get_result = instance_double(Google::Apis::SheetsV4::Spreadsheet)
        allow(spreadsheet_get_result).to receive(:sheets).and_return([sheet])
        allow(sheets_service).to receive(:get_spreadsheet).and_return(spreadsheet_get_result)

        # Mock clear_values and batch_update_values
        allow(sheets_service).to receive(:clear_values)
        batch_update_result = instance_double(Google::Apis::SheetsV4::BatchUpdateValuesResponse)
        allow(batch_update_result).to receive(:responses).and_return([])
        allow(sheets_service).to receive(:batch_update_values).and_return(batch_update_result)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        writer.call

        trade.reload
        expect(trade.spreadsheet_tab_name).to eq('user_with_special_chars_')
      end
    end

    context 'when Google Sheets credentials are not configured' do
      before do
        allow(Rails.application.credentials).to receive(:google_sheets).and_return(nil)
      end

      it 'raises SpreadsheetError' do
        # The error is raised during initialization when credentials are nil
        expect { GoogleSheetWriter.new(event, trade, admin_user) }.to raise_error(GoogleSheetWriter::SpreadsheetError)
      end
    end

    context 'when Google API returns 404 error for get_spreadsheet' do
      it 'clears spreadsheet_id and raises SpreadsheetError' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        event.update!(spreadsheet_id: 'existing-spreadsheet-id')

        error = Google::Apis::ClientError.new("notFound")
        allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        expect { writer.call }.to raise_error(GoogleSheetWriter::SpreadsheetError)
        expect(event.reload.spreadsheet_id).to be_nil
      end
    end

    context 'when Google API returns rate limit error' do
      it 'raises RateLimitError' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        event.update!(spreadsheet_id: 'existing-spreadsheet-id')

        error = Google::Apis::ClientError.new("rateLimitExceeded")
        allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        expect { writer.call }.to raise_error(GoogleSheetWriter::RateLimitError)
      end
    end

    context 'when Google API returns permission denied error' do
      it 'raises SpreadsheetError' do
        sheets_service = instance_double(Google::Apis::SheetsV4::SheetsService)
        allow(GoogleSheetsConfig).to receive(:sheets_client).and_return(sheets_service)

        event.update!(spreadsheet_id: 'existing-spreadsheet-id')

        error = Google::Apis::ClientError.new("Permission denied")
        allow(sheets_service).to receive(:get_spreadsheet).and_raise(error)

        writer = GoogleSheetWriter.new(event, trade, admin_user)
        expect { writer.call }.to raise_error(GoogleSheetWriter::SpreadsheetError)
      end
    end
  end
end
