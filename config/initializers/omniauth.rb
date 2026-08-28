Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_OAUTH_CLIENT_ID"],
           ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
           name: "google",
           scope: [ :profile, :email ]

  # Twitter OAuth 1.0a integration
  # omniauth-twitter gem (v1.5.0) supports OAuth 1.0a flow only.
  # Uses API Key and API Secret (equivalent to consumer_key/secret in OAuth 1.0a terminology).
  # Note: OAuth 1.0a does not support the 'scope' concept (scope is OAuth 2.0 feature).
  # See: https://github.com/arunagw/omniauth-twitter/blob/master/README.md
  provider :twitter,
           ENV["TWITTER_OAUTH_API_KEY"],
           ENV["TWITTER_OAUTH_API_SECRET"],
           name: "twitter",
           callback_path: "/auth/twitter/callback"
end

OmniAuth.config.path_prefix = "/auth"

if Rails.env.test?
  OmniAuth.config.test_mode = true
end
