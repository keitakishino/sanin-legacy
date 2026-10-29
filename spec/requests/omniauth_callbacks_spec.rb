require "rails_helper"

RSpec.describe "OmniAuth Callbacks", type: :request do
  describe "GET /auth/google/callback" do
    context "when creating a new OAuth user" do
      before do
        start_signup_with_invitation
        mock_google_auth(uid: "google_123", email: "newuser@example.com", name: nil)
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

      context "with an invitation in session" do
        before do
          start_signup_with_invitation
        end

        it "does not create a new user" do
          expect {
            get "/auth/google/callback"
          }.not_to change(User, :count)
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
    end

    context "when the account is not linked and no invitation is in session" do
      before do
        mock_google_auth(uid: "google_no_invite", email: "noinvite@example.com")
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

      it "redirects to signin_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "displays the correct alert message" do
        get "/auth/google/callback"
        expect(flash[:alert]).to eq("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end

      it "clears the signup_token from session" do
        get "/auth/google/callback"
        expect(session[:signup_token]).to be_nil
      end

      it "does not set session user_id" do
        get "/auth/google/callback"
        expect(session[:user_id]).to be_nil
      end

      it "shows the error message on the signin page" do
        get "/auth/google/callback"
        follow_redirect!
        expect(response.body).to include("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end
    end

    context "when the invitation in session is no longer available" do
      before do
        @invitation = start_signup_with_invitation
        @invitation.update_columns(status: "revoked")
        mock_google_auth(uid: "google_revoked", email: "revoked@example.com")
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

      it "redirects to signin_path" do
        get "/auth/google/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "displays the alert message" do
        get "/auth/google/callback"
        expect(flash[:alert]).to eq("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end

      it "clears the signup_token from session" do
        get "/auth/google/callback"
        expect(session[:signup_token]).to be_nil
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
        @invitation = start_signup_with_invitation
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

      it "marks the invitation as used" do
        get "/auth/google/callback"
        @invitation.reload
        expect(@invitation.status).to eq("used")
        expect(@invitation.used_by).to eq(User.last)
      end
    end

    context "when email local part conflicts with existing username" do
      let!(:existing_user) { create(:user, username: "conflict") }

      before do
        start_signup_with_invitation
        mock_google_auth(uid: "google_999", email: "conflict@example.com", name: nil)
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
        start_signup_with_invitation
        mock_google_auth(uid: "google_multi", email: "testuser@example.com", name: nil)
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
        start_signup_with_invitation
        mock_google_auth(uid: "google_timestamp", email: "conflict@example.com", name: nil)
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
        start_signup_with_invitation
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
        start_signup_with_invitation
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

  describe "GET /auth/discord/callback" do
    context "when creating a new OAuth user" do
      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "123456789012", email: "newuser@example.com", name: nil, global_name: nil)
      end

      it "creates a new user with the OAuth email" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq("newuser@example.com")
        expect(user.username).to eq("newuser")
      end

      it "creates an OAuth user without password_digest" do
        get "/auth/discord/callback"
        user = User.last
        expect(user.password_digest).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/discord/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.provider).to eq("discord")
        expect(identity.uid).to eq("123456789012")
        expect(identity.user_id).to eq(User.last.id)
      end

      it "sets the session user_id" do
        get "/auth/discord/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to root_path" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(root_path)
      end

      it "creates new user when oauth identity does not exist" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1).and change(Identity, :count).by(1)
      end
    end

    context "when logging in with existing identity" do
      let(:user) { create(:user, email: "existing@example.com") }
      let!(:identity) { create(:discord_identity, user: user, uid: "987654321098") }

      before do
        mock_discord_auth(uid: "987654321098", email: "existing@example.com")
      end

      it "does not create a new user" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(User, :count)
      end

      it "does not create a new identity" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(Identity, :count)
      end

      it "logs in the existing user when identity exists" do
        get "/auth/discord/callback"
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root_path" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(root_path)
      end

      context "with an invitation in session" do
        before do
          start_signup_with_invitation
        end

        it "does not create a new user" do
          expect {
            get "/auth/discord/callback"
          }.not_to change(User, :count)
        end

        it "logs in the existing user" do
          get "/auth/discord/callback"
          expect(session[:user_id]).to eq(user.id)
        end

        it "redirects to root_path" do
          get "/auth/discord/callback"
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context "when the account is not linked and no invitation is in session" do
      before do
        mock_discord_auth(uid: "discord_no_invite", email: "noinvite@example.com")
      end

      it "does not create a new user" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(User, :count)
      end

      it "does not create a new identity" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(Identity, :count)
      end

      it "redirects to signin_path" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "displays the correct alert message" do
        get "/auth/discord/callback"
        expect(flash[:alert]).to eq("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end

      it "clears the signup_token from session" do
        get "/auth/discord/callback"
        expect(session[:signup_token]).to be_nil
      end

      it "does not set session user_id" do
        get "/auth/discord/callback"
        expect(session[:user_id]).to be_nil
      end

      it "shows the error message on the signin page" do
        get "/auth/discord/callback"
        follow_redirect!
        expect(response.body).to include("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end
    end

    context "when OAuth auth_hash is missing" do
      before do
        clear_omniauth_mocks
      end

      it "displays an error flash message" do
        get "/auth/discord/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when email is nil" do
      before do
        @invitation = start_signup_with_invitation
        mock_discord_auth_with_nil_email(uid: "555666777888")
      end

      it "creates a new user without email" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to be_nil
      end

      it "creates a new identity linked to the user" do
        expect {
          get "/auth/discord/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end

      it "logs in the user" do
        get "/auth/discord/callback"
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "marks the invitation as used" do
        get "/auth/discord/callback"
        @invitation.reload
        expect(@invitation.status).to eq("used")
        expect(@invitation.used_by).to eq(User.last)
      end
    end

    context "when email local part conflicts with existing username" do
      let!(:existing_user) { create(:user, username: "conflict") }

      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "444333222111", email: "conflict@example.com", name: nil, global_name: nil)
      end

      it "creates a new user with a suffixed username" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.username).to eq("conflict1")
      end

      it "creates a new identity for the user" do
        expect {
          get "/auth/discord/callback"
        }.to change(Identity, :count).by(1)

        identity = Identity.last
        expect(identity.user_id).to eq(User.last.id)
      end
    end

    context "when uid is missing from auth_hash" do
      before do
        OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
          provider: "discord",
          uid: nil,
          info: {
            email: "test@example.com",
            name: "Test User"
          }
        )
      end

      it "displays an error flash message" do
        get "/auth/discord/callback"
        expect(flash[:alert]).to include("OAuth認可に失敗しました")
      end

      it "redirects to signin_path" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(signin_path)
      end

      it "does not create a new user" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(User, :count)
      end
    end

    context "when identity creation fails due to TOCTOU race condition" do
      let(:existing_user) { create(:user, email: "existing@example.com") }
      let!(:existing_identity) { create(:discord_identity, user: existing_user, uid: "111222333444") }

      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "111222333444", email: "newemail@example.com")

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
        get "/auth/discord/callback"
        expect(session[:user_id]).to eq(existing_user.id)
      end

      it "redirects to root_path when identity is found in rescue" do
        get "/auth/discord/callback"
        expect(response).to redirect_to(root_path)
      end

      it "does not create a duplicate identity" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(Identity, :count)
      end
    end
  end

  describe "external display name" do
    context "C1: Discord with global_name" do
      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "80351110224678001", email: "dc1@example.com", global_name: "DiscordDisplay", name: "discord_handle")
      end

      it "creates user with global_name as username" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.username).to eq("DiscordDisplay")
      end

      it "stores global_name in identity.username" do
        get "/auth/discord/callback"
        identity = Identity.last
        expect(identity.username).to eq("DiscordDisplay")
      end
    end

    context "C2: Discord with name only" do
      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "80351110224678002", email: "dc2@example.com", global_name: nil, name: "discord_handle")
      end

      it "creates user with name as username" do
        expect {
          get "/auth/discord/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.username).to eq("discord_handle")
      end

      it "stores name in identity.username" do
        get "/auth/discord/callback"
        identity = Identity.last
        expect(identity.username).to eq("discord_handle")
      end
    end

    context "C3: Google with name" do
      before do
        start_signup_with_invitation
        mock_google_auth(uid: "g_disp_1", email: "gg1@example.com", name: "GoogleName")
      end

      it "creates user with Google name as username" do
        expect {
          get "/auth/google/callback"
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.username).to eq("GoogleName")
      end

      it "stores name in identity.username" do
        get "/auth/google/callback"
        identity = Identity.last
        expect(identity.username).to eq("GoogleName")
      end
    end

    context "Google with name containing spaces" do
      before do
        start_signup_with_invitation
        mock_google_auth(uid: "g_disp_1b", email: "gg1b@example.com", name: "Google Name")
      end

      it "creates user with name sanitized" do
        get "/auth/google/callback"
        user = User.last
        expect(user.username).to eq("Google_Name")
      end

      it "stores original name in identity.username" do
        get "/auth/google/callback"
        identity = Identity.last
        expect(identity.username).to eq("Google Name")
      end
    end

    context "when display name cannot be retrieved" do
      before do
        start_signup_with_invitation
        mock_google_auth(uid: "g_disp_2", email: "gg2@example.com", name: nil)
      end

      it "stores nil in identity.username" do
        get "/auth/google/callback"
        identity = Identity.last
        expect(identity.username).to be_nil
      end
    end

    context "C8: display name without alphanumeric characters" do
      before do
        start_signup_with_invitation
        mock_google_auth(uid: "g_disp_3", email: "fallback@example.com", name: "山田")
      end

      it "creates user with email local part as fallback" do
        get "/auth/google/callback"
        user = User.last
        expect(user.username).to eq("fallback")
      end

      it "stores original display name in identity.username" do
        get "/auth/google/callback"
        identity = Identity.last
        expect(identity.username).to eq("山田")
      end
    end

    context "Discord with display name shorter than 3 characters" do
      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "80351110224678003", email: "fb2@example.com", global_name: "ab", name: nil)
      end

      it "creates user with email local part as fallback" do
        get "/auth/discord/callback"
        user = User.last
        expect(user.username).to eq("fb2")
      end

      it "stores short display name in identity.username" do
        get "/auth/discord/callback"
        identity = Identity.last
        expect(identity.username).to eq("ab")
      end
    end

    context "C9: display name conflicts with existing user" do
      let!(:existing_user) { create(:user, username: "DiscordDisplay") }

      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "80351110224678004", email: "dc4@example.com", global_name: "DiscordDisplay", name: "handle")
      end

      it "creates user with conflict suffix" do
        get "/auth/discord/callback"
        user = User.last
        expect(user.username).to eq("DiscordDisplay1")
      end
    end

    context "display name exceeding 50 characters" do
      let(:long_name) { "a" * 60 }

      before do
        start_signup_with_invitation
        mock_discord_auth(uid: "80351110224678005", email: "long@example.com", global_name: long_name, name: "handle")
      end

      it "creates user with truncated username" do
        get "/auth/discord/callback"
        user = User.last
        expect(user.username).to eq("a" * 50)
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

    it "shows the error on the signin page" do
      get "/auth/failure"
      follow_redirect!
      expect(request.path).to eq(signin_path)
      expect(response.body).to include("OAuth認可がキャンセルされました")
    end
  end
end
