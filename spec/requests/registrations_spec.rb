require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /signup" do
    context "with valid signup_token" do
      let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }
      let(:token) { invitation.generate_signup_token }

      it "returns 200 and shows signup form" do
        get "/signup", params: { token: token }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sign Up")
        expect(response.body).to include("Email & Password")
        expect(response.body).to include("Google")
        expect(response.body).to include("X (Twitter)")
      end

      it "saves token to session" do
        get "/signup", params: { token: token }

        expect(session[:signup_token]).to eq(token)
      end
    end

    context "with no token" do
      it "returns 403" do
        get "/signup"

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with invalid token" do
      it "returns 403" do
        get "/signup", params: { token: "invalid_token_xyz" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with expired token" do
      let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }
      let(:token) do
        token = invitation.generate_signup_token
        invitation.update(expires_at: 1.hour.ago)
        token
      end

      it "returns 403" do
        get "/signup", params: { token: token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with used token" do
      let(:user) { create(:user) }
      let(:invitation) { create(:invitation, status: :used, used_by: user, used_at: Time.current) }
      let(:token) { invitation.generate_signup_token }

      it "returns 403" do
        get "/signup", params: { token: token }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /signup (email)" do
    let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }
    let(:token) { invitation.generate_signup_token }

    before do
      get "/signup", params: { token: token }
    end

    context "with valid email and password" do
      let(:params) do
        {
          email: "newuser@example.com",
          password: "SecurePassword123",
          password_confirmation: "SecurePassword123",
          auth_method: "email"
        }
      end

      it "creates a user" do
        expect do
          post "/signup", params: params
        end.to change { User.count }.by(1)
      end

      it "creates user with general role" do
        post "/signup", params: params

        user = User.last
        expect(user.role).to eq("general")
      end

      it "creates user with generated username" do
        post "/signup", params: params

        user = User.last
        expect(user.username).to eq("newuser")
      end

      it "creates Identity (none for email signup)" do
        post "/signup", params: params

        user = User.last
        expect(user.identities.count).to eq(0)
      end

      it "marks invitation as used" do
        post "/signup", params: params

        expect(invitation.reload.status).to eq("used")
        expect(invitation.reload.used_by).to eq(User.last)
      end

      it "logs in the user" do
        post "/signup", params: params

        expect(session[:user_id]).to eq(User.last.id)
      end

      it "clears signup_token from session" do
        post "/signup", params: params

        expect(session[:signup_token]).to be_nil
      end

      it "redirects to root_path" do
        post "/signup", params: params

        expect(response).to redirect_to(root_path)
      end
    end

    context "with mismatched passwords" do
      let(:params) do
        {
          email: "newuser@example.com",
          password: "SecurePassword123",
          password_confirmation: "DifferentPassword456",
          auth_method: "email"
        }
      end

      it "does not create a user" do
        expect do
          post "/signup", params: params
        end.not_to change { User.count }
      end

      it "returns 422" do
        post "/signup", params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows error message" do
        post "/signup", params: params

        expect(response.body).to include("ユーザー作成に失敗しました")
      end

      it "does not mark invitation as used" do
        post "/signup", params: params

        expect(invitation.reload.status).to eq("active")
      end
    end

    context "with password too short" do
      let(:params) do
        {
          email: "newuser@example.com",
          password: "short",
          password_confirmation: "short",
          auth_method: "email"
        }
      end

      it "does not create a user" do
        expect do
          post "/signup", params: params
        end.not_to change { User.count }
      end

      it "returns 422" do
        post "/signup", params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows password error message" do
        post "/signup", params: params

        expect(response.body).to include("パスワード")
      end
    end

    context "with duplicate email" do
      let(:existing_user) { create(:user, email: "duplicate@example.com") }
      let(:params) do
        {
          email: existing_user.email,
          password: "SecurePassword123",
          password_confirmation: "SecurePassword123",
          auth_method: "email"
        }
      end

      it "does not create a user" do
        existing_user
        expect do
          post "/signup", params: params
        end.not_to change { User.count }
      end

      it "returns 422" do
        existing_user
        post "/signup", params: params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows email error message" do
        existing_user
        post "/signup", params: params

        expect(response.body).to include("メール")
      end
    end
  end

  describe "POST /signup (email) with no signup_token in session" do
    let(:params) do
      {
        email: "newuser@example.com",
        password: "SecurePassword123",
        password_confirmation: "SecurePassword123",
        auth_method: "email"
      }
    end

    it "returns 403" do
      post "/signup", params: params

      expect(response).to have_http_status(:forbidden)
    end

    it "does not create a user" do
      expect do
        post "/signup", params: params
      end.not_to change { User.count }
    end
  end

  describe "POST /signup (OAuth)" do
    let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }
    let(:token) { invitation.generate_signup_token }

    before do
      get "/signup", params: { token: token }
    end

    context "with Google OAuth" do
      it "redirects to /auth/google" do
        post "/signup", params: { auth_method: "google" }

        expect(response).to redirect_to("/auth/google")
      end
    end

    context "with Twitter OAuth" do
      it "redirects to /auth/twitter" do
        post "/signup", params: { auth_method: "twitter" }

        expect(response).to redirect_to("/auth/twitter")
      end
    end

    context "with invalid auth_method" do
      it "returns 422" do
        post "/signup", params: { auth_method: "invalid" }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows error message" do
        post "/signup", params: { auth_method: "invalid" }

        expect(response.body).to include("無効な認証方式です")
      end
    end
  end

  describe "OAuth callback with signup_token" do
    let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }
    let(:token) { invitation.generate_signup_token }
    let(:uid) { "123456789" }
    let(:email) { "oauthuser@example.com" }

    context "with new OAuth user via signup" do
      before do
        get "/signup", params: { token: token }
        mock_google_auth(uid: uid, email: email)
      end

      it "creates a user" do
        expect do
          post "/auth/google/callback"
        end.to change { User.count }.by(1)
      end

      it "creates an identity" do
        expect do
          post "/auth/google/callback"
        end.to change { Identity.count }.by(1)
      end

      it "marks invitation as used" do
        post "/auth/google/callback"

        expect(invitation.reload.status).to eq("used")
        expect(invitation.reload.used_by).to eq(User.last)
      end

      it "clears signup_token from session" do
        post "/auth/google/callback"

        expect(session[:signup_token]).to be_nil
      end

      it "logs in the user" do
        post "/auth/google/callback"

        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to root_path" do
        post "/auth/google/callback"

        expect(response).to redirect_to(root_path)
      end
    end

    context "with existing identity via signup" do
      let!(:user) { create(:user, email: email) }
      let!(:identity) { create(:identity, user: user, provider: "google", uid: uid) }

      before do
        get "/signup", params: { token: token }
        mock_google_auth(uid: uid, email: email)
      end

      it "does not create a new user" do
        expect do
          post "/auth/google/callback"
        end.not_to change { User.count }
      end

      it "marks invitation as used" do
        post "/auth/google/callback"

        expect(invitation.reload.status).to eq("used")
        expect(invitation.reload.used_by).to eq(user)
      end

      it "clears signup_token from session" do
        post "/auth/google/callback"

        expect(session[:signup_token]).to be_nil
      end

      it "logs in the existing user" do
        post "/auth/google/callback"

        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root_path" do
        post "/auth/google/callback"

        expect(response).to redirect_to(root_path)
      end
    end

    context "with OAuth without signup_token (normal login)" do
      before do
        mock_google_auth(uid: uid, email: email)
      end

      it "should not attempt to use invitation" do
        expect do
          post "/auth/google/callback"
        end.not_to change { invitation.reload.status }
      end

      it "should create user and login normally" do
        post "/auth/google/callback"

        expect(session[:user_id]).to be_present
      end
    end
  end

  describe "Regression: Existing /signin route" do
    context "GET /signin" do
      it "works normally" do
        get "/signin"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sign In")
      end
    end

    context "POST /signin with email/password" do
      let!(:user) do
        User.create!(
          username: "testuser",
          email: "user@example.com",
          password: "SecurePass123",
          password_confirmation: "SecurePass123",
          role: :general
        )
      end

      it "logs in successfully" do
        post "/signin", params: { email: user.email, password: "SecurePass123" }

        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
