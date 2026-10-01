require "rails_helper"

RSpec.describe "docker-compose.yml" do
  let(:compose_config) { YAML.safe_load_file(Rails.root.join("docker-compose.yml")) }
  let(:app_environment) { compose_config.dig("services", "app", "environment") }

  describe "app service environment" do
    it "does not set CAPYBARA_APP_HOST so the remote Chrome reaches the app container by its hostname" do
      expect(app_environment).not_to have_key("CAPYBARA_APP_HOST")
    end

    it "keeps SELENIUM_REMOTE_URL pointing to the Chrome service" do
      expect(app_environment["SELENIUM_REMOTE_URL"]).to eq("http://chrome:4444")
    end
  end
end
