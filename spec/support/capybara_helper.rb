require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-extensions")
  options.add_argument("--disable-setuid-sandbox")
  options.add_argument("--single-process")
  options.add_argument("--disable-background-networking")
  options.add_argument("--disable-breakpad")
  options.add_argument("--disable-client-side-phishing-detection")
  options.add_argument("--disable-default-apps")
  options.add_argument("--disable-hang-monitor")
  options.add_argument("--disable-popup-blocking")
  options.add_argument("--disable-prompt-on-repost")
  options.add_argument("--disable-sync")
  options.add_argument("--enable-automation")
  options.add_argument("--password-store=basic")
  options.add_argument("--use-mock-keychain")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

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
