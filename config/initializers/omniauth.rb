Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_OAUTH_CLIENT_ID"],
           ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
           name: "google",
           scope: [ :profile, :email ]

  # Discord OAuth 2.0 integration
  # Explicit scope required to get email; gem default is 'identify' only
  provider :discord,
           ENV["DISCORD_OAUTH_CLIENT_ID"],
           ENV["DISCORD_OAUTH_CLIENT_SECRET"],
           scope: "identify email"
end

OmniAuth.config.path_prefix = "/auth"

if Rails.env.test?
  OmniAuth.config.test_mode = true
  # In test mode, allow both GET and POST requests to OmniAuth routes
  OmniAuth.config.allowed_request_methods = [ :get, :post ]
  # Suppress the warning about allowing GET requests in test mode
  OmniAuth.config.silence_get_warning = true
end
