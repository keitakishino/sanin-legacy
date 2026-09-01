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

    context "when timestamp fallback username is needed" do
      # Create 101 users to exhaust the retry counter:
      # candidates are: conflict, conflict1, conflict2, ..., conflict100
      let!(:existing_users) do
        # Create "conflict" and "conflict1" through "conflict100"
        [
          create(:user, username: "conflict")
        ] + (1..100).map do |i|
          create(:user, username: "conflict#{i}")
        end
      end

      before do
        mock_google_auth(uid: "google_timestamp", email: "conflict@example.com")
      end

      it "creates a new user with timestamp-based fallback username" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.username).to match(/^conflict_\d{10}$/)
      end

      it "ensures timestamp fallback username does not exceed 50 characters" do
        get "/auth/google/callback"
        new_user = User.last
        expect(new_user.username.length).to be <= 50
      end

      it "creates identity for the user with timestamp username" do
        expect {
          get "/auth/google/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.uid).to eq("google_timestamp")
        expect(identity.user_id).to eq(User.last.id)
      end
    end

    context "when identity creation fails due to TOCTOU race condition" do
      let(:existing_user) { create(:user, email: "existing@example.com") }
      let!(:existing_identity) { create(:google_identity, user: existing_user, uid: "google_race") }

      before do
        mock_google_auth(uid: "google_race", email: "newemail@example.com")

        # Simulate TOCTOU race: first check returns nil, but identity already exists in DB
        # We use a counter to return nil on first call and the existing identity on subsequent calls
        find_by_call_count = 0
        allow(Identity).to receive(:find_by) do |**kwargs|
          find_by_call_count += 1
          if find_by_call_count == 1 && kwargs[:uid] == "google_race"
            # First call returns nil (simulating the identity not yet created at that moment)
            nil
          else
            # Subsequent calls find the identity (another request created it in the meantime)
            Identity.where(kwargs).first
          end
        end
      end

      it "handles TOCTOU race condition by logging in with the existing user" do
        get "/auth/google/callback"
        expect(session[:user_id]).to eq(existing_user.id)
      end

      it "redirects to root_path when identity is found in rescue" do
        get "/auth/google/callback"
        expect(response).to redirect_to(root_path)
      end

      it "does not create a duplicate identity" do
        expect {
          get "/auth/google/callback"
        }.not_to change(Identity, :count)
      end

      it "logs in with the user linked to the existing identity, not the newly created user" do
        # Transaction ensures that if Identity creation fails, User is rolled back
        # so we log in with the existing user linked to the existing identity
        get "/auth/google/callback"
        expect(session[:user_id]).to eq(existing_user.id)
      end

      it "does not create an orphaned user due to transaction rollback" do
        user_count_before = User.count
        expect {
          get "/auth/google/callback"
        }.not_to change(User, :count)
        # Verify the session has the correct user
        expect(session[:user_id]).to eq(existing_user.id)
      end
    end

    context "when identity creation fails due to TOCTOU race with transaction isolation" do
      let(:existing_user) { create(:user, email: "existing@example.com") }
      let!(:existing_identity) { create(:google_identity, user: existing_user, uid: "google_toctou_orphan") }

      before do
        mock_google_auth(uid: "google_toctou_orphan", email: "newemail@example.com")

        # Simulate TOCTOU race: first check returns nil (in google action), but by the time
        # transaction tries to create identity, another request has already created it
        find_by_call_count = 0
        allow(Identity).to receive(:find_by) do |**kwargs|
          find_by_call_count += 1
          if find_by_call_count == 1 && kwargs[:uid] == "google_toctou_orphan"
            # First call in google action returns nil
            nil
          else
            # Subsequent calls find the identity (another request created it during transaction)
            Identity.where(kwargs).first
          end
        end
      end

      it "does not create orphaned user when identity uniqueness constraint fails in transaction" do
        user_count_before = User.count
        expect {
          get "/auth/google/callback"
        }.not_to change(User, :count)
        # Verify the session is logged in as the existing user
        expect(session[:user_id]).to eq(existing_user.id)
      end

      it "ensures transaction rollback prevents orphaned user" do
        get "/auth/google/callback"
        # All users should be the ones that were created before this request
        all_users = User.pluck(:email).sort
        original_users = User.where("created_at < ?", 1.minute.ago).pluck(:email).sort
        # The new email from OAuth should not be in the database
        expect(all_users).not_to include("newemail@example.com")
      end
    end
  end

  describe "GET /auth/twitter/callback" do
    context "when creating a new OAuth user" do
      before do
        mock_twitter_auth(uid: "123456789012", email: "newuser@example.com")
end

      it "creates a new user with the OAuth email" do
        expect {
          get "/auth/twitter/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq("newuser@example.com")
        expect(user.username).to eq("newuser")
      end

      it "creates an OAuth user without password_digest" do
        get "/auth/twitter/callback"
        user = User.last
        expect(user.password_digest).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/twitter/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.provider).to eq("twitter")
        expect(identity.uid).to eq("123456789012")
        expect(identity.user_id).to eq(User.last.id)
      end

      it "sets the session user_id" do
        get "/auth/twitter/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to root_path" do
        get "/auth/twitter/callback"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when logging in with existing identity" do
      let(:user) { create(:user, email: "existing@example.com") }
      let!(:identity) { create(:twitter_identity, user: user, uid: "987654321098") }

      before do
        mock_twitter_auth(uid: "987654321098", email: "existing@example.com")
      end

      it "does not create a new user" do
        expect {
          get "/auth/twitter/callback"
        }.not_to change(User, :count)
      end

      it "does not create a new identity" do
        expect {
          get "/auth/twitter/callback"
        }.not_to change(Identity, :count)
      end

      it "logs in the existing user" do
        get "/auth/twitter/callback"
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root_path" do
        get "/auth/twitter/callback"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when OAuth auth_hash is missing" do
      before do
        clear_omniauth_mocks
      end

      it "displays an error flash message" do
        get "/auth/twitter/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/twitter/callback"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when email is nil" do
      before do
        mock_twitter_auth_with_nil_email(uid: "555666777888")
      end

      it "creates a new user without email" do
        expect {
          get "/auth/twitter/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/twitter/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end

      it "logs in the user" do
        get "/auth/twitter/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end
    end

    context "when email local part conflicts with existing username" do
      let!(:existing_user) { create(:user, username: "conflict") }

      before do
        mock_twitter_auth(uid: "444333222111", email: "conflict@example.com")
      end

      it "creates a new user with a suffixed username" do
        expect {
          get "/auth/twitter/callback"
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.username).to eq("conflict1")
      end

      it "creates a new identity for the user" do
        expect {
          get "/auth/twitter/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end
    end

    context "when uid is missing from auth_hash" do
      before do
        OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
          provider: "twitter",
          uid: nil,
          info: {
            email: "test@example.com",
            name: "Test User"
          }
        )
      end

      it "displays an error flash message" do
        get "/auth/twitter/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/twitter/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "does not create a new user" do
        expect {
          get "/auth/twitter/callback"
        }.not_to change(User, :count)
      end
    end

    context "when identity creation fails due to TOCTOU race condition" do
      let(:existing_user) { create(:user, email: "existing@example.com") }
      let!(:existing_identity) { create(:twitter_identity, user: existing_user, uid: "111222333444") }

      before do
        mock_twitter_auth(uid: "111222333444", email: "newemail@example.com")

        find_by_call_count = 0
        allow(Identity).to receive(:find_by) do |**kwargs|
          find_by_call_count += 1
          if find_by_call_count == 1 && kwargs[:uid] == "111222333444"
            nil
          else
            Identity.where(kwargs).first
          end
        end
      end

      it "handles TOCTOU race condition by logging in with the existing user" do
        get "/auth/twitter/callback"
        expect(session[:user_id]).to eq(existing_user.id)
      end

      it "redirects to root_path when identity is found in rescue" do
        get "/auth/twitter/callback"
        expect(response).to redirect_to(root_path)
      end

      it "does not create a duplicate identity" do
        expect {
          get "/auth/twitter/callback"
        }.not_to change(Identity, :count)
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
