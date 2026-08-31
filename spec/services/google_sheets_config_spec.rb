require 'rails_helper'

RSpec.describe GoogleSheetsConfig, type: :service do
  describe '.sheets_client' do
    context 'when google_sheets credentials are configured' do
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

      it 'returns a SheetsService instance' do
        client = GoogleSheetsConfig.sheets_client
        expect(client).to be_a(Google::Apis::SheetsV4::SheetsService)
      end

      it 'sets the authorization on the client' do
        client = GoogleSheetsConfig.sheets_client
        expect(client.authorization).not_to be_nil
      end
    end

    context 'when google_sheets credentials are not configured' do
      before do
        allow(Rails.application.credentials).to receive(:google_sheets).and_return(nil)
      end

      it 'raises CredentialsNotConfiguredError' do
        expect { GoogleSheetsConfig.sheets_client }.to raise_error(GoogleSheetsConfig::CredentialsNotConfiguredError)
      end

      it 'includes a helpful error message' do
        expect { GoogleSheetsConfig.sheets_client }.to raise_error do |error|
          expect(error.message).to include('Rails credentials に google_sheets 設定がありません')
        end
      end
    end

    context 'when google_sheets credentials are blank' do
      before do
        allow(Rails.application.credentials).to receive(:google_sheets).and_return({})
      end

      it 'raises CredentialsNotConfiguredError' do
        expect { GoogleSheetsConfig.sheets_client }.to raise_error(GoogleSheetsConfig::CredentialsNotConfiguredError)
      end
    end
  end

  describe '.drive_client' do
    context 'when google_sheets credentials are configured' do
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

      it 'returns a DriveService instance' do
        client = GoogleSheetsConfig.drive_client
        expect(client).to be_a(Google::Apis::DriveV3::DriveService)
      end

      it 'sets the authorization on the client' do
        client = GoogleSheetsConfig.drive_client
        expect(client.authorization).not_to be_nil
      end
    end

    context 'when google_sheets credentials are not configured' do
      before do
        allow(Rails.application.credentials).to receive(:google_sheets).and_return(nil)
      end

      it 'raises CredentialsNotConfiguredError' do
        expect { GoogleSheetsConfig.drive_client }.to raise_error(GoogleSheetsConfig::CredentialsNotConfiguredError)
      end
    end
  end

  describe 'SCOPES constant' do
    it 'includes SheetsV4 AUTH_SPREADSHEETS scope' do
      expect(GoogleSheetsConfig::SCOPES).to include(Google::Apis::SheetsV4::AUTH_SPREADSHEETS)
    end

    it 'includes DriveV3 AUTH_DRIVE scope' do
      expect(GoogleSheetsConfig::SCOPES).to include(Google::Apis::DriveV3::AUTH_DRIVE)
    end
  end
end
