require "rails_helper"

# 認可リクエストに載る scope を、実際に組み立てられた URL で確かめる。
#
# omniauth-google-oauth2 は scope をカンマ・空白区切りの「文字列」として解釈し、
# BASE_SCOPES（%w[profile email openid]）に無いものを
# https://www.googleapis.com/auth/<scope> に変換する。配列やシンボルで渡すと
# ここで存在しないスコープが作られ、Google に
# 「Some requested scopes were invalid」と拒否される（2026-10-31 に本番で発生）。
RSpec.describe "OmniAuth の認可リクエスト", type: :request do
  # OmniAuth.config.test_mode が true だとプロバイダへ出ずにコールバックへ直行するので、
  # 実際の認可 URL を見るために切る。rails_helper が config レベルの before で true にするため、
  # それより後に走る group レベルの before で上書きする
  before do
    @original_test_mode = OmniAuth.config.test_mode
    @original_protection = ActionController::Base.allow_forgery_protection
    OmniAuth.config.test_mode = false
    # ここで確かめたいのは scope なので、CSRF は対象外（omniauth_csrf_spec.rb が見ている）
    ActionController::Base.allow_forgery_protection = false
  end

  after do
    ActionController::Base.allow_forgery_protection = @original_protection
    OmniAuth.config.test_mode = @original_test_mode
  end

  def authorize_url(provider)
    post "/auth/#{provider}"
    URI.parse(response.location.to_s)
  end

  it "Google に email と profile を要求する（URL 化されたスコープにしない）" do
    uri = authorize_url("google")

    expect(uri.host).to eq("accounts.google.com")
    expect(CGI.parse(uri.query.to_s)["scope"].first).to eq("email profile")
  end

  it "Discord に identify と email を要求する（既定の identify だけにしない）" do
    uri = authorize_url("discord")

    expect(uri.host).to eq("discord.com")
    expect(CGI.parse(uri.query.to_s)["scope"].first).to eq("identify email")
  end
end
