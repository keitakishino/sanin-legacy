require "rails_helper"

# 認証系エンドポイントの総当たり対策（レート制限）の回帰テスト。
RSpec.describe "認証系エンドポイントのレート制限", type: :request do
  let(:store) { Rails.application.config.x.rate_limit_store }

  describe "POST /signin" do
    let!(:user) { create(:user, email: "limited@example.com", password: "password123") }

    it "5 分あたり 10 回を超えると 429 を返す" do
      10.times do
        post signin_path, params: { email: user.email, password: "wrong-password" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      post signin_path, params: { email: user.email, password: "wrong-password" }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("試行回数が多すぎます")
    end

    it "上限に達したあとは、正しいパスワードでもサインインできない" do
      11.times { post signin_path, params: { email: user.email, password: "wrong-password" } }

      post signin_path, params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:too_many_requests)
      expect(session[:user_id]).to be_nil
    end

    it "ウィンドウが明けると再び試行できる" do
      11.times { post signin_path, params: { email: user.email, password: "wrong-password" } }
      expect(response).to have_http_status(:too_many_requests)

      travel_to(6.minutes.from_now) do
        post signin_path, params: { email: user.email, password: "password123" }

        expect(response).to redirect_to(root_path)
        expect(session[:user_id]).to eq(user.id)
      end
    end

    it "GET /signin はレート制限の対象外" do
      11.times { post signin_path, params: { email: user.email, password: "wrong-password" } }

      get signin_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /invite" do
    it "10 分あたり 10 回を超えると 429 を返す" do
      10.times do
        post "/invite", params: { invitation: { code: "wrongcode123" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      post "/invite", params: { invitation: { code: "wrongcode123" } }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("試行回数が多すぎます")
    end

    it "429 でも招待コード入力フォームを描画できる" do
      11.times { post "/invite", params: { invitation: { code: "wrongcode123" } } }

      expect(response.body).to include("招待コード")
    end
  end

  describe "POST /signup" do
    it "10 分あたり 10 回を超えると 429 を返す" do
      invitation = create(:invitation)
      token = invitation.generate_signup_token
      get "/signup", params: { token: token }

      10.times do
        post "/signup", params: { auth_method: "unknown" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      post "/signup", params: { auth_method: "unknown" }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("試行回数が多すぎます")
    end
  end

  describe "ストアの分離" do
    it "Rails.cache をクリアしてもレート制限のカウンタは消えない" do
      user = create(:user, email: "isolated@example.com", password: "password123")
      11.times { post signin_path, params: { email: user.email, password: "wrong-password" } }
      expect(response).to have_http_status(:too_many_requests)

      Rails.cache.clear

      post signin_path, params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "専用ストアにカウンタが載っている" do
      user = create(:user, email: "counted@example.com", password: "password123")
      post signin_path, params: { email: user.email, password: "wrong-password" }

      expect(store.read("rate-limit:sessions:signin:127.0.0.1")).to eq(1)
    end
  end
end
