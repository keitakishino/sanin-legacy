require "rails_helper"

# マイページの連携ボタンは /mypage/identities/:provider に POST し、
# Users::IdentityLinksController#create が 307 で /auth/:provider へ同じボディを再送させる。
# Rails の per-form CSRF トークンはフォームの action のパスに紐づくため、
# /mypage/... 用のトークンでは /auth/... で検証が通らず、本番で
# ActionController::InvalidAuthenticityToken になっていた（2026-10-31）。
#
# この経路は system spec では捕まらなかった。失敗して流れが止まるのを
# `visit "/auth/*/callback"` で手動で迂回していて、壊れた状態が仕様として
# 固定されていたため（同コミットで削除済み）。
RSpec.describe "OmniAuth の CSRF 検証", type: :request do
  let(:user) { create(:user) }

  # request spec は rails_helper で verify_authenticity_token をスタブするが、
  # それは controller 側の検証だけで、OmniAuth のミドルウェア（TokenVerifier）には効かない。
  # ここで見たいのはミドルウェア側なので、保護が有効であることを明示しておく
  before do
    @original_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/signin", params: { email: user.email, password: "password123" }
  end

  after do
    ActionController::Base.allow_forgery_protection = @original_protection
  end

  %w[discord google].each do |provider|
    it "マイページの #{provider} 連携ボタンのトークンで、307 再送先の /auth/#{provider} の検証が通る" do
      get "/mypage"
      expect(response).to have_http_status(:ok)

      field = Nokogiri::HTML(response.body).at_css(%(form[action="/mypage/identities/#{provider}"] input[name="authenticity_token"]))
      expect(field).to be_present, "マイページに #{provider} の連携ボタンが見つかりません"
      token = field["value"]

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
