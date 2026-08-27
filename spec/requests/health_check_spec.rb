require 'rails_helper'

RSpec.describe 'Health Checks', type: :request do
  describe 'GET /' do
    it 'returns 200 status' do
      get '/', headers: { 'Host' => 'localhost' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /up' do
    it 'returns 200 status' do
      get '/up', headers: { 'Host' => 'localhost' }
      expect(response).to have_http_status(:ok)
    end
  end
end
