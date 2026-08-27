# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../config/environment', __dir__)

# Allow all hosts in test environment to prevent HostAuthorization errors in request specs
# by explicitly setting them
Rails.application.config.hosts = ["127.0.0.1", "localhost", "example.com", "www.example.com"]

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
