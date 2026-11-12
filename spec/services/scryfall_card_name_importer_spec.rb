require "rails_helper"

RSpec.describe ScryfallCardNameImporter do
  describe "#call" do
    let(:importer) { described_class.new }

    let(:sample_response) do
      {
        object: "catalog",
        total_values: 3,
        data: [ "Lightning Bolt", "Black Lotus", "Counterspell" ]
      }
    end

    it "[C4] 取り込むと card_names に Scryfall のカード名が入る" do
      stub_scryfall_card_names_response(sample_response)

      result = importer.call

      expect(result[:success]).to be true
      expect(result[:created_count]).to eq(3)
      expect(result[:skipped_count]).to eq(0)
      expect(CardName.count).to eq(3)
      expect(CardName.pluck(:name)).to contain_exactly("Lightning Bolt", "Black Lotus", "Counterspell")
    end

    it "[C4] 2 回実行しても重複しない" do
      stub_scryfall_card_names_response(sample_response)

      first_result = importer.call
      expect(first_result[:created_count]).to eq(3)

      second_result = importer.call
      expect(second_result[:created_count]).to eq(0)
      expect(second_result[:skipped_count]).to eq(3)
      expect(CardName.count).to eq(3)
      expect(CardName.group(:name).count.values.max).to eq(1)
    end

    it "[C5] Scryfall へのリクエストに User-Agent と Accept が付く" do
      captured_request = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
        captured_request = req
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return("200")
        allow(response).to receive(:body).and_return(sample_response.to_json)
        response
      end

      importer.call

      expect(captured_request["User-Agent"]).to eq(ScryfallHttp::USER_AGENT)
      expect(captured_request["Accept"]).to eq(ScryfallHttp::ACCEPT)
    end

    it "既存の名前がある状態で新しい名前だけ追加される" do
      create(:card_name, name: "Lightning Bolt")

      stub_scryfall_card_names_response(sample_response)

      result = importer.call

      expect(result[:created_count]).to eq(2)
      expect(result[:skipped_count]).to eq(1)
      expect(CardName.count).to eq(3)
    end

    context "API failures" do
      it "200 以外で success: false になる" do
        stub_scryfall_api_error_response(404, "Not Found")

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:created_count]).to eq(0)
        expect(result[:skipped_count]).to eq(0)
      end

      it "タイムアウトで success: false になる" do
        stub_scryfall_api_timeout

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include("API request timeout")
      end

      it "不正 JSON で success: false になる" do
        stub_scryfall_api_invalid_json

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include("Failed to parse")
      end

      it "data 欠落で success: false になる" do
        response_without_data = {
          object: "catalog",
          total_values: 0
        }
        stub_scryfall_card_names_response(response_without_data)

        result = importer.call

        expect(result[:success]).to be false
        expect(result[:message]).to include("Invalid Scryfall API response structure")
      end
    end

    private

    def stub_scryfall_card_names_response(response_data)
      allow_any_instance_of(Net::HTTP).to receive(:request) do
        response = instance_double(Net::HTTPResponse)
        allow(response).to receive(:code).and_return("200")
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
        allow(response).to receive(:code).and_return("200")
        allow(response).to receive(:body).and_return("{ invalid json ")
        response
      end
    end
  end
end
