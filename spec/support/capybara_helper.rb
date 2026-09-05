require 'capybara/rails'
require 'capybara/rspec'

Capybara.configure do |config|
  config.default_driver = :selenium_chrome_headless
  config.server_port = 3005
end

RSpec.configure do |config|
  config.include Capybara::DSL

  # For system tests, use database_cleaner strategy
  # since transactions don't work with Capybara's threaded driver
  config.before(:each, type: :system) do
    I18n.locale = :ja
  end

  config.after(:each, type: :system) do
    I18n.locale = I18n.default_locale
  end
end
