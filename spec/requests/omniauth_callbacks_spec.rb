require "rails_helper"

RSpec.describe "OmniAuth Callbacks", type: :request do
  describe "GET /auth/google/callback" do
    context "when creating a new OAuth user" do
      before do
        mock_google_auth(uid: "google_123", email: "newuser@example.com")
      end

      it "creates a new user with the OAuth email" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq("newuser@example.com")
        expect(user.username).to eq("newuser")
      end

      it "creates an OAuth user without password_digest" do
        get "/auth/google/callback"
        user = User.last
        expect(user.password_digest).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/google/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.provider).to eq("google")
        expect(identity.uid).to eq("google_123")
        expect(identity.user_id).to eq(User.last.id)
      end

      it "sets the session user_id" do
        get "/auth/google/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to root_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logging in with existing identity" do
      let(:user) { create(:user, email: "existing@example.com") }
      let!(:identity) { create(:google_identity, user: user, uid: "google_456") }

      before do
        mock_google_auth(uid: "google_456", email: "existing@example.com")
      end

      it "does not create a new user" do
        expect {
          get "/auth/google/callback"
        }.not_to change(User, :count)
      end

      it "does not create a new identity" do
        expect {
          get "/auth/google/callback"
        }.not_to change(Identity, :count)
      end

      it "logs in the existing user" do
        get "/auth/google/callback"
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when OAuth auth_hash is missing" do
      before do
        clear_omniauth_mocks
      end

      it "displays an error flash message" do
        get "/auth/google/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when email is nil" do
      before do
        mock_google_auth_with_nil_email(uid: "google_789")
      end

      it "creates a new user without email" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/google/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end

      it "logs in the user" do
        get "/auth/google/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end
    end

    context "when email local part conflicts with existing username" do
      let!(:existing_user) { create(:user, username: "conflict") }

      before do
        mock_google_auth(uid: "google_999", email: "conflict@example.com")
      end

      it "creates a new user with a suffixed username" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.username).to eq("conflict1")
      end

      it "creates a new identity for the user" do
        expect {
          get "/auth/google/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end
    end

    context "when multiple username conflicts exist" do
      let!(:user1) { create(:user, username: "testuser") }
      let!(:user2) { create(:user, username: "testuser1") }
      let!(:user3) { create(:user, username: "testuser2") }

      before do
        mock_google_auth(uid: "google_multi", email: "testuser@example.com")
      end

      it "creates a new user with the next available suffix" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.username).to eq("testuser3")
      end
    end

    context "when uid is missing from auth_hash" do
      before do
        OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
          provider: "google",
          uid: nil,
          info: {
            email: "test@example.com",
            name: "Test User"
          }
        )
      end

      it "displays an error flash message" do
        get "/auth/google/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "does not create a new user" do
        expect {
          get "/auth/google/callback"
        }.not_to change(User, :count)
      end
    end
  end

  describe "GET /auth/failure" do
    it "displays an error flash message" do
      get "/auth/failure"
      expect(flash[:alert]).to include("OAuth認可がキャンセルされました")
    end

    it "redirects to signin_path" do
      get "/auth/failure"
      expect(response).to redirect_to(signin_path)
    end
  end
end
