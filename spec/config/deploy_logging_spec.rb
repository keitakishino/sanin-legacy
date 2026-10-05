require "rails_helper"

RSpec.describe "config/deploy.yml" do
  let(:deploy_config) do
    deploy_yml_path = Rails.root.join("config", "deploy.yml")
    template = File.read(deploy_yml_path)
    erb_result = ERB.new(template).result
    YAML.safe_load(erb_result)
  end

  describe "logging configuration" do
    it "has Docker log rotation configured with max-size 10m and max-file 5" do
      expect(deploy_config.dig("logging", "driver")).to eq("json-file")
      expect(deploy_config.dig("logging", "options", "max-size")).to eq("10m")
      expect(deploy_config.dig("logging", "options", "max-file")).to eq(5)
    end
  end
end
