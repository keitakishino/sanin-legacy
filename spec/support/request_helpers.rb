module RequestHelpers
  def modern_browser_headers
    { "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
