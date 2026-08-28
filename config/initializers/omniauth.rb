Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_OAUTH_CLIENT_ID"],
           ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
           name: "google",
           scope: [ :profile, :email ]

  provider :twitter,
           ENV["TWITTER_OAUTH_API_KEY"],
           ENV["TWITTER_OAUTH_API_SECRET"],
           name: "twitter"
end

OmniAuth.config.path_prefix = "/auth"

if Rails.env.test?
  OmniAuth.config.test_mode = true
end
