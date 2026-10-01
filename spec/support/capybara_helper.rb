require "capybara/rails"
require "capybara/rspec"
require "selenium-webdriver"
require "tmpdir"
require "net/http"
require "json"
require "socket"

SYSTEM_SPEC_WINDOW_SIZE = [ 1400, 1400 ].freeze
CAPYBARA_SERVER_PORT = 3005

def chrome_options
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-extensions")
  options.add_argument("--disable-setuid-sandbox")
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
  options.add_argument("--window-size=1400,1400")
  options
end

def wait_for_grid(url)
  max_retries = 60
  retry_interval = 1

  max_retries.times do |attempt|
    begin
      uri = URI("#{url.chomp("/")}/status")
      response = Net::HTTP.get(uri)
      body = JSON.parse(response)
      return if body.dig("value", "ready") == true
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, EOFError
      # Grid not ready yet, retry
    end

    sleep(retry_interval) if attempt < max_retries - 1
  end

  raise "Selenium Grid at #{url} did not become ready within #{max_retries} seconds"
end

Capybara.register_driver :chrome_headless do |app|
  if ENV["SELENIUM_REMOTE_URL"]
    wait_for_grid(ENV["SELENIUM_REMOTE_URL"])
    Capybara::Selenium::Driver.new(
      app,
      browser: :remote,
      url: ENV["SELENIUM_REMOTE_URL"],
      options: chrome_options
    )
  else
    options = chrome_options
    options.binary = "/usr/bin/chromium" if File.exist?("/usr/bin/chromium")
    options.add_argument("--user-data-dir=#{Dir.mktmpdir("chromium-user-data")}")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
end

Capybara.configure do |config|
  config.server = :puma, { Silent: true }
  config.server_port = CAPYBARA_SERVER_PORT
  config.default_max_wait_time = 5
  config.default_driver = :chrome_headless
  config.javascript_driver = :chrome_headless

  if ENV["SELENIUM_REMOTE_URL"]
    config.server_host = "0.0.0.0"
    config.app_host = "http://#{ENV.fetch("CAPYBARA_APP_HOST") { Socket.gethostname }}:#{CAPYBARA_SERVER_PORT}"
  end
end

module CapybaraAuthHelpers
  def sign_in(user)
    visit signin_path
    fill_in "email", with: user.email
    fill_in "password", with: user.password
    click_button "サインイン"
    page.assert_current_path(root_path)
  end

  def resize_window_to(width, height)
    page.current_window.resize_to(width, height)
  end
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include CapybaraAuthHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :chrome_headless
    page.current_window.resize_to(*SYSTEM_SPEC_WINDOW_SIZE)
    @original_default_locale = I18n.default_locale
    I18n.default_locale = :ja
    I18n.locale = :ja
  end

  config.after(:each, type: :system) do
    I18n.default_locale = @original_default_locale || :en
    I18n.locale = I18n.default_locale
  end
end
