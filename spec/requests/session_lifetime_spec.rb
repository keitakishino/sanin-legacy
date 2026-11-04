require "rails_helper"

# セッションの有効期限と失効の回帰テスト。
RSpec.describe "セッションの有効期限と失効", type: :request do
  let!(:user) { create(:user, email: "lifetime@example.com", password: "password123") }

  after { travel_back }

  def sign_in_with_password(password: "password123")
    post signin_path, params: { email: user.email, password: password }
  end

  describe "クッキー側のアイドルタイムアウト" do
    it "セッションクッキーに有効期限が付く" do
      sign_in_with_password

      set_cookie = Array(response.headers["set-cookie"]).join("\n")
      expect(set_cookie).to include("_sanin_legacy_session")
      expect(set_cookie.downcase).to include("expires=")
    end

    it "一定期間アクセスしないとセッションが切れる" do
      sign_in_with_password
      expect(session[:user_id]).to eq(user.id)

      travel 8.days
      get mypage_path

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end

    it "アクセスし続けている間は切れない" do
      sign_in_with_password

      travel 5.days
      get mypage_path

      expect(response).to have_http_status(:ok)
      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe "サーバ側の絶対的な上限（SESSION_MAX_AGE）" do
    it "使い続けていても発行から 14 日を過ぎたら切れる" do
      sign_in_with_password

      travel 5.days
      get mypage_path
      expect(response).to have_http_status(:ok)

      travel 5.days
      get mypage_path
      expect(response).to have_http_status(:ok)

      travel 5.days
      get mypage_path

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end
  end

  describe "パスワード変更による失効" do
    it "別経路でパスワードが変わると、発行済みのセッションは通らなくなる" do
      sign_in_with_password
      expect(session[:user_id]).to eq(user.id)

      user.update!(password: "newpassword456", password_confirmation: "newpassword456")

      get mypage_path

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end

    it "自分でパスワードを変えたときは、そのままサインインしたままでいられる" do
      sign_in_with_password

      patch mypage_path, params: {
        user: {
          username: user.username,
          email: user.email,
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }
      }
      expect(response).to redirect_to(mypage_path)

      get mypage_path

      expect(response).to have_http_status(:ok)
      expect(session[:user_id]).to eq(user.id)
    end

    it "パスワード変更後はセッション ID も入れ替わる" do
      sign_in_with_password
      before_id = session.id&.public_id

      patch mypage_path, params: {
        user: {
          username: user.username,
          email: user.email,
          current_password: "password123",
          password: "newpassword456",
          password_confirmation: "newpassword456"
        }
      }

      expect(session.id&.public_id).not_to eq(before_id)
    end
  end

  describe "ユーザーが消えた場合" do
    it "セッションは通らなくなる" do
      sign_in_with_password
      user.destroy!

      get mypage_path

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end
  end

  describe "User#session_auth_token" do
    it "パスワードを変えると値が変わる" do
      before_token = user.session_auth_token
      user.update!(password: "newpassword456", password_confirmation: "newpassword456")

      expect(user.session_auth_token).not_to eq(before_token)
    end

    it "パスワード以外の変更では値が変わらない" do
      before_token = user.session_auth_token
      user.update!(username: "renamed_user")

      expect(user.session_auth_token).to eq(before_token)
    end
  end
end
