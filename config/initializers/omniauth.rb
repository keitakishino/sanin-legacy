Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_OAUTH_CLIENT_ID"],
           ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
           name: "google",
           # scope は「カンマ区切りの文字列」で渡す。配列やシンボルで渡すと
           # omniauth-google-oauth2 の BASE_SCOPES（%w[profile email openid]）と一致せず、
           # https://www.googleapis.com/auth/profile のような存在しないスコープに変換されて
           # Google に「Some requested scopes were invalid」と拒否される
           scope: "email,profile"

  # Discord OAuth 2.0 integration
  # Explicit scope required to get email; gem default is 'identify' only
  provider :discord,
           ENV["DISCORD_OAUTH_CLIENT_ID"],
           ENV["DISCORD_OAUTH_CLIENT_SECRET"],
           scope: "identify email"
end

OmniAuth.config.path_prefix = "/auth"

# OmniAuth はコールバック URL をリクエストの Host（または X-Forwarded-Host）から組み立てる。
# 偽装されたホストでコールバック URL を作られないよう、受け付けるホストを明示する。
# 開発・テストは localhost や www.example.com を使うので本番系だけに適用する
if Rails.env.production?
  OmniAuth.config.allowed_hosts = [ "sanin-legacy.win", "staging.sanin-legacy.win" ]
end

if Rails.env.test?
  OmniAuth.config.test_mode = true
  # In test mode, allow both GET and POST requests to OmniAuth routes
  OmniAuth.config.allowed_request_methods = [ :get, :post ]
  # Suppress the warning about allowing GET requests in test mode
  OmniAuth.config.silence_get_warning = true
end
