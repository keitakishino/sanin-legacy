RSpec.configure do |config|
  config.after do
    ErrorNotification::DiscordSender.reset!
  end
end
