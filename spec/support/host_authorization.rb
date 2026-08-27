RSpec.configure do |config|
  config.before(:suite) do
    # Override the host authorization middleware in test environment
    if Rails.env.test?
      Rails.application.config.middleware.delete ActionDispatch::HostAuthorization rescue nil
    end
  end
end
