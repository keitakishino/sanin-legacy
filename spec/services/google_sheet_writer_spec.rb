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
        allow(spreadsheet_get_result).to receive(:sheets).and_return([ sheet ])
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
        allow(spreadsheet_get_result).to receive(:sheets).and_return([ sheet ])
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
        allow(spreadsheet_get_result).to receive(:sheets).and_return([ sheet ])
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
        allow(spreadsheet_get_result).to receive(:sheets).and_return([ sheet ])
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

  describe '#build_spreadsheet_rows' do
    let(:event) { create(:event, spreadsheet_id: 'test-spreadsheet-id') }
    let(:trade) { create(:trade, event: event, user: user) }

    before do
      allow(Rails.application.credentials).to receive(:google_sheets).and_return(mock_credentials)
    end

    context 'with offers and wants having amounts' do
      before do
        create(:trade_card_offer, trade: trade, card_name: 'Card A', quantity: 2, amount: 100)
        create(:trade_card_offer, trade: trade, card_name: 'Card B', quantity: 3, amount: 50)
        create(:trade_card_want, trade: trade, card_name: 'Card C', quantity: 1, amount: 200)
        create(:trade_card_want, trade: trade, card_name: 'Card D', quantity: 4, amount: 75)
      end

      it 'includes "小計" in the header row' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        header_row = rows[0]
        expect(header_row).to include("小計")
        expect(header_row).to eq([ "カード名", "枚数", "言語", "状態", "特殊", "枠", "PW", "金額", "小計" ])
      end

      it 'calculates offers subtotal correctly (amount × quantity)' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        # Find offer rows (after "【 出すカード 】" row, filter out non-card rows)
        offer_section_index = rows.find_index { |row| row[0] == "【 出すカード 】" }
        want_section_index = rows.find_index { |row| row[0] == "【 欲しいカード 】" }
        offer_rows = rows[(offer_section_index + 1)...want_section_index].reject { |row| row.all? { |cell| cell == "" } }

        expect(offer_rows.length).to eq(2)
        expect(offer_rows[0][-1]).to eq("200")  # 2 × 100
        expect(offer_rows[1][-1]).to eq("150")  # 3 × 50
      end

      it 'calculates wants subtotal correctly (amount × quantity)' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        # Find want rows (after "【 欲しいカード 】" row, filter out blank rows and section headers)
        want_section_index = rows.find_index { |row| row[0] == "【 欲しいカード 】" }
        summary_index = rows.find_index { |row| row[0] == "合計" }
        want_rows = rows[(want_section_index + 1)...summary_index].reject { |row| row.all? { |cell| cell == "" } || row[0]&.start_with?("【") }

        expect(want_rows.length).to eq(2)
        expect(want_rows[0][-1]).to eq("200")  # 1 × 200
        expect(want_rows[1][-1]).to eq("300")  # 4 × 75
      end

      it 'ensures all card data rows have 9 columns' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        # Check header row and all card data rows (skip section headers and blank rows)
        rows.each_with_index do |row, index|
          if row[0] && (row[0].start_with?("【") || row[0] == "合計") || row.all? { |cell| cell == "" }
            # Section headers, category labels, and blank rows can be variable length
            next
          else
            # All other rows should have 9 columns
            expect(row.length).to eq(9), "Row #{index} (#{row[0]}) has #{row.length} columns, expected 9"
          end
        end
      end
    end

    context 'with offers having nil amounts' do
      before do
        create(:trade_card_offer, trade: trade, card_name: 'Card A', quantity: 2, amount: nil)
        create(:trade_card_offer, trade: trade, card_name: 'Card B', quantity: 3, amount: 50)
      end

      it 'outputs empty string for subtotal when amount is nil' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        offer_section_index = rows.find_index { |row| row[0] == "【 出すカード 】" }
        want_section_index = rows.find_index { |row| row[0] == "【 欲しいカード 】" }
        offer_rows = rows[(offer_section_index + 1)...want_section_index].reject { |row| row.all? { |cell| cell == "" } }

        expect(offer_rows[0][-1]).to eq("")  # nil amount → empty string subtotal
        expect(offer_rows[1][-1]).to eq("150")  # 3 × 50
      end
    end

    context 'with wants having nil amounts' do
      before do
        create(:trade_card_want, trade: trade, card_name: 'Card A', quantity: 2, amount: nil)
        create(:trade_card_want, trade: trade, card_name: 'Card B', quantity: 3, amount: 75)
      end

      it 'outputs empty string for subtotal when amount is nil' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        want_section_index = rows.find_index { |row| row[0] == "【 欲しいカード 】" }
        summary_index = rows.find_index { |row| row[0] == "合計" }
        want_rows = rows[(want_section_index + 1)...summary_index].reject { |row| row.all? { |cell| cell == "" } || row[0]&.start_with?("【") }

        expect(want_rows[0][-1]).to eq("")  # nil amount → empty string subtotal
        expect(want_rows[1][-1]).to eq("225")  # 3 × 75
      end
    end

    context 'summary rows structure' do
      before do
        create(:trade_card_offer, trade: trade, card_name: 'Card A', quantity: 2, amount: 100)
        create(:trade_card_want, trade: trade, card_name: 'Card B', quantity: 1, amount: 200)
      end

      it 'ensures all summary data rows have 9 elements' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        rows = writer.send(:build_spreadsheet_rows)

        # Find all summary rows (those that start with "出すカード合計", "欲しいカード合計", "差額" - exclude "合計" section header)
        summary_rows = rows.select { |row| (row[0]&.include?("合計") || row[0]&.include?("差額")) && row[0] != "合計" }

        summary_rows.each do |row|
          expect(row.length).to eq(9), "Summary row '#{row[0]}' has #{row.length} columns, expected 9"
        end
      end
    end
  end

  describe '#sanitize_tab_name' do
    let(:event) { create(:event, spreadsheet_id: 'test-spreadsheet-id') }
    let(:trade) { create(:trade, event: event, user: user) }

    before do
      allow(Rails.application.credentials).to receive(:google_sheets).and_return(mock_credentials)
    end

    context 'with special characters' do
      it 'replaces forward slash with underscore' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user/name')
        expect(result).to eq('user_name')
      end

      it 'replaces backslash with underscore' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user\\name')
        expect(result).to eq('user_name')
      end

      it 'replaces question mark with underscore' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user?name')
        expect(result).to eq('user_name')
      end

      it 'replaces asterisk with underscore' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user*name')
        expect(result).to eq('user_name')
      end

      it 'replaces square brackets with underscores' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user[name]')
        expect(result).to eq('user_name_')
      end

      it 'replaces multiple special characters at once' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'user/with\\special?chars*[test]')
        expect(result).to eq('user_with_special_chars__test_')
      end
    end

    context 'with character length constraints' do
      it 'truncates to 100 characters' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        long_name = 'a' * 101
        result = writer.send(:sanitize_tab_name, long_name)
        expect(result.length).to eq(100)
        expect(result).to eq('a' * 100)
      end

      it 'preserves content when under 100 characters' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        name = 'a' * 50
        result = writer.send(:sanitize_tab_name, name)
        expect(result).to eq('a' * 50)
      end

      it 'truncates exactly at 100 characters' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        name = 'a' * 100
        result = writer.send(:sanitize_tab_name, name)
        expect(result.length).to eq(100)
      end

      it 'truncates special characters when combined with length' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        long_name_with_special = 'a' * 50 + '/' + 'b' * 50 + '?'
        result = writer.send(:sanitize_tab_name, long_name_with_special)
        expect(result.length).to eq(100)
        expect(result).to include('_')
      end
    end

    context 'with normal names' do
      it 'returns unchanged name for valid input' do
        writer = GoogleSheetWriter.new(event, trade, admin_user)
        result = writer.send(:sanitize_tab_name, 'valid_username')
        expect(result).to eq('valid_username')
      end
    end
  end
end
