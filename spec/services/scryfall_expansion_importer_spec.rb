require 'rails_helper'

RSpec.describe ScryfallExpansionImporter, type: :service do
  describe '#call' do
    let(:importer) { described_class.new }

    let(:sample_sets_response) do
      {
        object: 'list',
        data: [
          {
            object: 'set',
            code: 'mh3',
            name: 'Modern Horizons 3',
            printed_name: 'モダンホライゾン3',
            set_type: 'expansion',
            released_at: '2024-06-14'
          },
          {
            object: 'set',
            code: 'bro',
            name: 'The Brothers\' War',
            printed_name: 'ザ・ブラザーズ・ウォー',
            set_type: 'expansion',
            released_at: '2022-11-18'
          },
          {
            object: 'set',
            code: 'prm',
            name: 'Premium Deck Series',
            printed_name: nil,
            set_type: 'promo',
            released_at: '2010-01-01'
          },
          {
            object: 'set',
            code: 't20',
            name: 'Tokens (2020)',
            printed_name: nil,
            set_type: 'token',
            released_at: '2020-01-01'
          }
        ],
        has_more: false
      }
    end

    context 'successful import' do
      it 'creates new expansions from Scryfall API' do
        stub_scryfall_api_response(sample_sets_response)

        result = importer.call

        expect(result[:success]).to be true
        expect(result[:created_count]).to eq(2)
        expect(result[:skipped_count]).to eq(2)
        expect(result[:error_count]).to eq(0)
      end

      it 'correctly normalizes set codes to uppercase' do
        stub_scryfall_api_response(sample_sets_response)

        importer.call

        expect(Expansion.find_by(scryfall_set_code: 'MH3')).to be_present
        expect(Expansion.find_by(scryfall_set_code: 'BRO')).to be_present
      end

      it 'saves English and Japanese names correctly' do
        stub_scryfall_api_response(sample_sets_response)

        importer.call

        mh3 = Expansion.find_by(scryfall_set_code: 'MH3')
        expect(mh3.name).to eq('Modern Horizons 3')
        expect(mh3.name_ja).to eq('モダンホライゾン3')

        bro = Expansion.find_by(scryfall_set_code: 'BRO')
        expect(bro.name).to eq('The Brothers\' War')
        expect(bro.name_ja).to eq('ザ・ブラザーズ・ウォー')
      end

      it 'handles missing Japanese names (nil)' do
        response_without_ja = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: nil,
              set_type: 'expansion',
              released_at: '2024-06-14'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_without_ja)

        importer.call

        mh3 = Expansion.find_by(scryfall_set_code: 'MH3')
        expect(mh3).to be_present
        expect(mh3.name_ja).to be_nil
      end

      it 'skips promo set type' do
        response_with_promo = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'prm',
              name: 'Premium Deck Series',
              printed_name: nil,
              set_type: 'promo',
              released_at: '2010-01-01'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_promo)

        importer.call

        expect(Expansion.find_by(scryfall_set_code: 'PRM')).to be_nil
      end

      it 'skips token set type' do
        response_with_token = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 't20',
              name: 'Tokens (2020)',
              printed_name: nil,
              set_type: 'token',
              released_at: '2020-01-01'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_token)

        importer.call

        expect(Expansion.find_by(scryfall_set_code: 'T20')).to be_nil
      end

      it 'counts correctly: 2 created (non-promo/token), 2 skipped (promo/token)' do
        stub_scryfall_api_response(sample_sets_response)

        result = importer.call

        expect(result[:created_count]).to eq(2)
        expect(result[:skipped_count]).to eq(2)
        expect(result[:error_count]).to eq(0)
      end
    end

    context 'when expansion already exists' do
      it 'skips existing expansions without updating' do
        existing = create(:expansion, scryfall_set_code: 'MH3', name: 'Old Name', name_ja: 'オールドネーム')
        stub_scryfall_api_response(sample_sets_response)

        importer.call

        existing.reload
        expect(existing.name).to eq('Old Name')
        expect(existing.name_ja).to eq('オールドネーム')
      end

      it 'increments skipped_count for existing expansions' do
        create(:expansion, scryfall_set_code: 'MH3')
        stub_scryfall_api_response(sample_sets_response)

        result = importer.call

        # Should have 1 created (BRO), 3 skipped (MH3 existing, PRM promo, T20 token), 0 errors
        expect(result[:skipped_count]).to eq(3)
        expect(result[:created_count]).to eq(1)
      end
    end

    context 'when API call fails' do
      it 'returns failure when API times out' do
        stub_scryfall_api_timeout

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include('API request timeout')
        expect(result[:created_count]).to eq(0)
      end

      it 'returns failure when API returns non-200 status' do
        stub_scryfall_api_error_response(404, 'Not Found')

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include('API returned status')
      end

      it 'returns failure when JSON parsing fails' do
        stub_scryfall_api_invalid_json

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include('Failed to parse')
      end

      it 'returns failure when API response lacks data key' do
        response_without_data = {
          object: 'list',
          has_more: false
        }
        stub_scryfall_api_response(response_without_data)

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid Scryfall API response structure')
      end

      it 'returns failure when API response data is not an array' do
        response_with_invalid_data = {
          object: 'list',
          data: 'not_an_array',
          has_more: false
        }
        stub_scryfall_api_response(response_with_invalid_data)

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid Scryfall API response structure')
      end

      it 'logs the error' do
        stub_scryfall_api_error_response(500, 'Internal Server Error')
        allow(Rails.logger).to receive(:error)

        importer.call

        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end

    context 'when database validation fails for individual sets' do
      it 'continues processing after a validation failure' do
        response_with_invalid = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'inv1',
              name: 'Invalid Set 1',
              printed_name: nil,
              set_type: 'expansion',
              released_at: '2024-01-01'
            },
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: 'モダンホライゾン3',
              set_type: 'expansion',
              released_at: '2024-06-14'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_invalid)

        # Simulate validation failure for the first set using and_wrap_original
        allow(Expansion).to receive(:create).and_wrap_original do |method, attrs|
          if attrs[:scryfall_set_code] == 'INV1'
            expansion = Expansion.new(attrs)
            expansion.errors.add(:name, "can't be blank")
            expansion
          else
            method.call(attrs)
          end
        end

        result = importer.call

        # Should still process the second set despite the first one failing
        expect(Expansion.find_by(scryfall_set_code: 'MH3')).to be_present
        expect(result[:error_count]).to eq(1)
        expect(result[:created_count]).to eq(1)
      end

      it 'logs individual set failures' do
        response_with_invalid = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'bad',
              name: 'Bad Set',
              printed_name: nil,
              set_type: 'expansion',
              released_at: '2024-01-01'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_invalid)

        allow(Expansion).to receive(:create) do |_attrs|
          expansion = Expansion.new
          expansion.errors.add(:name, "can't be blank")
          expansion
        end
        allow(Rails.logger).to receive(:error)

        importer.call

        expect(Rails.logger).to have_received(:error).at_least(:once)
      end

      it 'handles nil set code gracefully' do
        response_with_nil_code = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: nil,
              name: 'Set with nil code',
              printed_name: nil,
              set_type: 'expansion',
              released_at: '2024-01-01'
            },
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: 'モダンホライゾン3',
              set_type: 'expansion',
              released_at: '2024-06-14'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_nil_code)
        allow(Rails.logger).to receive(:error)

        result = importer.call

        # First set should error, second should be created
        expect(result[:error_count]).to eq(1)
        expect(result[:created_count]).to eq(1)
        expect(Expansion.find_by(scryfall_set_code: 'MH3')).to be_present
        expect(Rails.logger).to have_received(:error).with(include('Set code is nil or empty'))
      end

      it 'handles empty set code gracefully' do
        response_with_empty_code = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: '   ',
              name: 'Set with empty code',
              printed_name: nil,
              set_type: 'expansion',
              released_at: '2024-01-01'
            },
            {
              object: 'set',
              code: 'bro',
              name: 'The Brothers\' War',
              printed_name: 'ザ・ブラザーズ・ウォー',
              set_type: 'expansion',
              released_at: '2022-11-18'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response_with_empty_code)
        allow(Rails.logger).to receive(:error)

        result = importer.call

        # First set should error, second should be created
        expect(result[:error_count]).to eq(1)
        expect(result[:created_count]).to eq(1)
        expect(Expansion.find_by(scryfall_set_code: 'BRO')).to be_present
        expect(Rails.logger).to have_received(:error).with(include('Set code is nil or empty'))
      end
    end

    context 'when uniqueness constraint violation occurs (race condition)' do
      it 'treats uniqueness violation as skipped, not error' do
        response = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: 'モダンホライゾン3',
              set_type: 'expansion',
              released_at: '2024-06-14'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response)

        # Simulate uniqueness violation on create
        allow(Expansion).to receive(:create) do |attrs|
          expansion = Expansion.new(attrs)
          expansion.errors.add(:scryfall_set_code, :taken)
          expansion
        end

        result = importer.call

        # Should be counted as skipped, not error
        expect(result[:skipped_count]).to eq(1)
        expect(result[:error_count]).to eq(0)
      end

      it 'treats other validation errors as errors, not skipped' do
        response = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: 'モダンホライゾン3',
              set_type: 'expansion',
              released_at: '2024-06-14'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response)

        # Simulate other validation error on create
        allow(Expansion).to receive(:create) do |attrs|
          expansion = Expansion.new(attrs)
          expansion.errors.add(:name, "can't be blank")
          expansion
        end

        result = importer.call

        # Should be counted as error, not skipped
        expect(result[:error_count]).to eq(1)
        expect(result[:skipped_count]).to eq(0)
      end

      it 'processes multiple sets with race condition in middle' do
        response = {
          object: 'list',
          data: [
            {
              object: 'set',
              code: 'mh3',
              name: 'Modern Horizons 3',
              printed_name: 'モダンホライゾン3',
              set_type: 'expansion',
              released_at: '2024-06-14'
            },
            {
              object: 'set',
              code: 'bro',
              name: 'The Brothers\' War',
              printed_name: 'ザ・ブラザーズ・ウォー',
              set_type: 'expansion',
              released_at: '2022-11-18'
            },
            {
              object: 'set',
              code: 'grn',
              name: 'Guilds of Ravnica',
              printed_name: 'ラヴニカのギルド',
              set_type: 'expansion',
              released_at: '2018-10-05'
            }
          ],
          has_more: false
        }
        stub_scryfall_api_response(response)

        # Simulate race condition on second set
        allow(Expansion).to receive(:create).and_wrap_original do |method, attrs|
          if attrs[:scryfall_set_code] == 'BRO'
            expansion = Expansion.new(attrs)
            expansion.errors.add(:scryfall_set_code, :taken)
            expansion
          else
            method.call(attrs)
          end
        end

        result = importer.call

        # MH3 and GRN created, BRO skipped due to race condition
        expect(result[:created_count]).to eq(2)
        expect(result[:skipped_count]).to eq(1)
        expect(result[:error_count]).to eq(0)
        expect(Expansion.find_by(scryfall_set_code: 'MH3')).to be_present
        expect(Expansion.find_by(scryfall_set_code: 'GRN')).to be_present
      end

      it 'correctly identifies race condition error regardless of locale (Japanese)' do
        original_locale = I18n.locale
        begin
          I18n.locale = :ja

          response = {
            object: 'list',
            data: [
              {
                object: 'set',
                code: 'test_ja',
                name: 'Test Set',
                printed_name: 'テストセット',
                set_type: 'expansion',
                released_at: '2024-01-01'
              }
            ],
            has_more: false
          }
          stub_scryfall_api_response(response)

          # Simulate uniqueness violation with Japanese locale active
          allow(Expansion).to receive(:create) do |attrs|
            expansion = Expansion.new(attrs)
            expansion.errors.add(:scryfall_set_code, :taken)
            expansion
          end

          result = importer.call

          # Should be counted as skipped, not error, even in Japanese locale
          expect(result[:skipped_count]).to eq(1)
          expect(result[:error_count]).to eq(0)
        ensure
          I18n.locale = original_locale
        end
      end
    end

    context 'logging' do
      it 'logs API call start' do
        stub_scryfall_api_response(sample_sets_response)
        allow(Rails.logger).to receive(:info)

        importer.call

        expect(Rails.logger).to have_received(:info).with(include('Starting Scryfall expansion import'))
      end

      it 'logs number of sets fetched' do
        stub_scryfall_api_response(sample_sets_response)
        allow(Rails.logger).to receive(:info)

        importer.call

        expect(Rails.logger).to have_received(:info).with(include('Successfully fetched'))
      end

      it 'logs successful expansion creation' do
        stub_scryfall_api_response(sample_sets_response)
        allow(Rails.logger).to receive(:info)

        importer.call

        expect(Rails.logger).to have_received(:info).with(include('Created expansion')).at_least(:twice)
      end

      it 'logs completion message with counts' do
        stub_scryfall_api_response(sample_sets_response)
        allow(Rails.logger).to receive(:info)

        importer.call

        expect(Rails.logger).to have_received(:info).with(include('Expansion import completed'))
      end
    end

    private

    def stub_scryfall_api_response(response_data)
      allow_any_instance_of(Net::HTTP).to receive(:request) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return('200')
        allow(response).to receive(:body).and_return(response_data.to_json)
        response
      end
    end

    def stub_scryfall_api_error_response(status_code, body)
      allow_any_instance_of(Net::HTTP).to receive(:request) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return(status_code.to_s)
        allow(response).to receive(:body).and_return(body)
        response
      end
    end

    def stub_scryfall_api_timeout
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout)
    end

    def stub_scryfall_api_invalid_json
      allow_any_instance_of(Net::HTTP).to receive(:request) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return('200')
        allow(response).to receive(:body).and_return('{ invalid json ')
        response
      end
    end
  end
end
