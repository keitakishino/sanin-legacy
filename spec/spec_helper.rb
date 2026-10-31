# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

# OmniAuth の strategy は config/initializers/omniauth.rb の読み込み時に ENV を読む。
# 空のままだと client_id が無く、認可 URL を組み立てる経路（scope の確認など）を
# テストできないので、ダミー値を入れておく。環境変数が既にあればそちらを使う
ENV['GOOGLE_OAUTH_CLIENT_ID'] ||= 'test-google-client-id'
ENV['GOOGLE_OAUTH_CLIENT_SECRET'] ||= 'test-google-client-secret'
ENV['DISCORD_OAUTH_CLIENT_ID'] ||= 'test-discord-client-id'
ENV['DISCORD_OAUTH_CLIENT_SECRET'] ||= 'test-discord-client-secret'

require File.expand_path('../config/environment', __dir__)

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'

# Add additional requires below this line. Custom requires should be added as:
# require 'my/custom/module'
#
# The following line is provided for convenience purposes. It has the downside of increasing
# the boot-up time by auto-requiring all files in the support directory. Alternatively, you
# may explicitly require only the files you need.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  # Use color in output
  config.color = true

  # Use more verbose output format
  config.formatter = :documentation

  # Use transactional fixtures
  config.use_transactional_fixtures = true

  # Infer an example group's spec type from the file location.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
end
