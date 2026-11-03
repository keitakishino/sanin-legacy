require "rails_helper"

# セッション固定対策の回帰テスト。
# ログイン前に発行されたセッション ID が、認証後もそのまま使われていないことを確認する。
RSpec.describe "Session fixation", type: :request do
  let!(:user) { create(:user, email: "fixation@example.com", password: "password123") }

  def current_session_id
    session.id&.public_id
  end

  describe "パスワードでのサインイン" do
    it "サインイン前後でセッション ID が変わる" do
      get signin_path
      before_id = current_session_id
      expect(before_id).to be_present

      post signin_path, params: { email: user.email, password: "password123" }

      expect(session[:user_id]).to eq(user.id)
      expect(current_session_id).to be_present
      expect(current_session_id).not_to eq(before_id)
    end

    it "サインインに失敗したときはセッションを作り直さない" do
      get signin_path
      before_id = current_session_id

      post signin_path, params: { email: user.email, password: "wrong-password" }

      expect(session[:user_id]).to be_nil
      expect(current_session_id).to eq(before_id)
    end
  end

  describe "サインアウト" do
    it "セッションを破棄し、ID も変わる" do
      post signin_path, params: { email: user.email, password: "password123" }
      signed_in_id = current_session_id

      delete signout_path

      expect(session[:user_id]).to be_nil
      expect(current_session_id).not_to eq(signed_in_id)
    end
  end

  describe "OAuth でのサインイン" do
    let!(:identity) { create(:identity, user: user, provider: :google, uid: "123456789") }

    it "サインイン前後でセッション ID が変わる" do
      get signin_path
      before_id = current_session_id

      mock_google_auth(uid: "123456789", email: user.email)
      get "/auth/google/callback"

      expect(session[:user_id]).to eq(user.id)
      expect(current_session_id).not_to eq(before_id)
    end
  end

  describe "招待経由のサインアップ" do
    it "サインアップ前後でセッション ID が変わり、signup_token が残らない" do
      invitation = create(:invitation)
      token = invitation.generate_signup_token

      get "/signup", params: { token: token }
      before_id = current_session_id
      expect(session[:signup_token]).to eq(token)

      post "/signup", params: {
        auth_method: "email",
        email: "newcomer@example.com",
        username: "newcomer",
        password: "password123",
        password_confirmation: "password123"
      }

      expect(session[:user_id]).to eq(User.find_by(email: "newcomer@example.com").id)
      expect(session[:signup_token]).to be_nil
      expect(current_session_id).not_to eq(before_id)
      expect(invitation.reload).to be_status_used
    end
  end
end
