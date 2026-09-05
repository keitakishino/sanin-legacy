require 'capybara/rails'
require 'capybara/rspec'

Capybara.configure do |config|
  config.default_driver = :selenium_chrome_headless
  config.server_port = 3005
end

module CapybaraAuthHelpers
  def sign_in(user)
    # For system tests with Selenium: navigate to signin page and fill form
    # Note: Requires Selenium ChromeDriver to be available
    visit signin_path
    fill_in 'email', with: user.email
    fill_in 'password', with: user.password
    click_button 'サインイン'
  end
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include CapybaraAuthHelpers, type: :system

  # For system tests, use database_cleaner strategy
  # since transactions don't work with Capybara's threaded driver
  config.before(:each, type: :system) do
    I18n.locale = :ja
  end

  config.after(:each, type: :system) do
    I18n.locale = I18n.default_locale
  end
end
