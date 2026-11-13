require "rails_helper"
require "rake"

RSpec.describe "card_names:import_from_scryfall", type: :task do
  let(:rake_app) { Rake::Application.new }
  let(:rake_task) do
    rake_app.rake_require("tasks/card_names", [ Rails.root.join("lib").to_s ], [ "lib/tasks/card_names.rake" ])
    Rake::Task.define_task(:environment)
    Rake::Task["card_names:import_from_scryfall"]
  end

  after do
    rake_task.reenable
  end

  let(:sample_response) do
      {
        object: "catalog",
        total_values: 3,
        data: [ "Lightning Bolt", "Black Lotus", "Counterspell" ]
      }
    end

    it "[C4] rake を実行すると card_names に Scryfall のカード名が入る" do
      stub_scryfall_card_names_response(sample_response)

      rake_task.invoke

      expect(CardName.count).to eq(3)
      expect(CardName.pluck(:name)).to contain_exactly("Lightning Bolt", "Black Lotus", "Counterspell")
    end

    it "[C4] 2 回実行しても重複しない" do
      stub_scryfall_card_names_response(sample_response)

      rake_task.invoke
      expect(CardName.count).to eq(3)

      rake_task.reenable
      rake_task.invoke
      expect(CardName.count).to eq(3)
      expect(CardName.group(:name).count.values.max).to eq(1)
    end

    it "API が 500 のとき exit 1 になる" do
      stub_scryfall_api_error_response(500, "Internal Server Error")

      expect { rake_task.invoke }.to raise_error(SystemExit) do |exit_error|
        expect(exit_error.status).to eq(1)
      end
    end

    it "標準出力に \"Card name import completed\" が出る" do
      stub_scryfall_card_names_response(sample_response)

      expect { rake_task.invoke }.to output(/Card name import completed/).to_stdout
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
end
