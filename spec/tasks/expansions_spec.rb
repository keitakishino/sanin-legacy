require 'rails_helper'
require 'rake'

RSpec.describe 'expansions:import_from_scryfall', type: :task do
  let(:rake_app) { Rake::Application.new }
  let(:rake_task) do
    rake_app.rake_require('tasks/expansions', [ Rails.root.join('lib').to_s ], [ 'lib/tasks/expansions.rake' ])
    Rake::Task.define_task(:environment)
    Rake::Task['expansions:import_from_scryfall']
  end

  after do
    rake_task.reenable
  end

  let(:sample_response) do
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
        }
      ],
      has_more: false
    }
  end

  it 'successfully imports expansions from Scryfall' do
    stub_scryfall_api_response(sample_response)

    expect { rake_task.invoke }.not_to raise_error
  end

  it 'creates expansion records' do
    stub_scryfall_api_response(sample_response)

    rake_task.invoke

    expect(Expansion.find_by(scryfall_set_code: 'MH3')).to be_present
    expect(Expansion.find_by(scryfall_set_code: 'BRO')).to be_present
  end

  it 'outputs success message to stdout' do
    stub_scryfall_api_response(sample_response)

    expect { rake_task.invoke }.to output(/Expansion import completed/).to_stdout
  end

  it 'includes created count in output' do
    stub_scryfall_api_response(sample_response)

    expect { rake_task.invoke }.to output(/2 created/).to_stdout
  end

  it 'exits with code 1 when API fails' do
    stub_scryfall_api_error_response(500, 'Internal Server Error')

    expect { rake_task.invoke }.to raise_error(SystemExit) do |exit_error|
      expect(exit_error.status).to eq(1)
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
end
