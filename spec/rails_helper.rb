# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

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
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

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

  # Include FactoryBot methods (build, create, etc.) without the FactoryBot:: prefix.
  config.include FactoryBot::Syntax::Methods

  # Include time-travel helpers (freeze_time, travel_to, etc.).
  config.include ActiveSupport::Testing::TimeHelpers
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  # Disable CSRF protection for request specs in test.
  # Even though config/environments/test.rb sets hosts to an empty Set for host authorization,
  # CSRF verification still occurs in request specs. The `allow_forgery_protection = false`
  # setting does not fully disable CSRF verification in Rails 8.1 request specs, so we need
  # to stub the verification method explicitly.
  config.before(:each, type: :request) do
    allow_any_instance_of(ActionController::Base).to receive(:verify_authenticity_token)
  end
end
