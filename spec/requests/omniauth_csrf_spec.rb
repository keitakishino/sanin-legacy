require "rails_helper"

# OmniAuth は test_mode のとき mock_request_call に入り、request_validation_phase（CSRF 検証）を
# 丸ごと素通りする。そのため system spec でも通常の request spec でも、この経路の CSRF は
# 一度も検証されない。ここだけ test_mode を切って、本番と同じ経路を通す。
RSpec.describe "OmniAuth の CSRF 検証", type: :request do
  let(:user) { create(:user) }

  around do |example|
    original_test_mode = OmniAuth.config.test_mode
    original_protection = ActionController::Base.allow_forgery_protection
    OmniAuth.config.test_mode = false
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original_protection
    OmniAuth.config.test_mode = original_test_mode
  end

  before do
    post "/signin", params: { email: user.email, password: "password123" }
  end

  # マイページの連携ボタンは /mypage/identities/:provider に POST し、307 で /auth/:provider へ
  # 同じボディが再送される。Rails の per-form CSRF トークンはフォームの action のパスに紐づくため、
  # /mypage/... 用のトークンでは /auth/... で検証が通らず、本番で
  # ActionController::InvalidAuthenticityToken になっていた（2026-10-31）。
  %w[discord google].each do |provider|
    it "マイページの #{provider} 連携ボタンのトークンで、307 再送先の /auth/#{provider} の検証が通る" do
      get "/mypage"
      expect(response).to have_http_status(:ok)

      form = Nokogiri::HTML(response.body).at_css(%(form[action="/mypage/identities/#{provider}"] input[name="authenticity_token"]))
      expect(form).to be_present, "マイページに #{provider} の連携ボタンが見つかりません"
      token = form["value"]

      post "/mypage/identities/#{provider}", params: { authenticity_token: token }
      expect(response).to have_http_status(:temporary_redirect)

      # 307 を受けたブラウザは、同じボディを再送する
      post "/auth/#{provider}", params: { authenticity_token: token }

      expect(response.location).not_to include("/auth/failure"),
        "CSRF 検証に失敗しました（#{response.location}）"
      expect(response).to have_http_status(:found)
    end
  end

  it "トークンが無ければ /auth/discord は拒否される" do
    post "/auth/discord"

    expect(response.location).to include("/auth/failure")
  end
end
