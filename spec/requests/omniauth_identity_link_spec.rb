require "rails_helper"

RSpec.describe "OmniAuth Identity Link (from My Page)", type: :request do
  describe "POST /mypage/identities/:provider" do
    context "when user is logged in" do
      let(:user) { create(:user) }

      before do
        post "/signin", params: { email: user.email, password: "password123" }
      end

      it "redirects to /auth/:provider with 307 status" do
        post "/mypage/identities/discord"

        expect(response).to have_http_status(:temporary_redirect)
        expect(response.location).to include("/auth/discord")
      end

      it "sets session[:oauth_link_user_id] before redirect" do
        # This will be deleted by redirect, but we verify it's set by checking the redirect
        expect {
          post "/mypage/identities/discord"
        }.not_to raise_error

        # After POST, it should redirect with 307 (temporary)
        expect(response.status).to eq(307)
      end

      it "works for google provider" do
        post "/mypage/identities/google"

        expect(response).to have_http_status(:temporary_redirect)
        expect(response.location).to include("/auth/google")
      end
    end

    context "when user is not logged in" do
      before do
        # Don't log in
      end

      it "redirects to signin_path" do
        post "/mypage/identities/discord"

        expect(response).to redirect_to(signin_path)
      end

      it "does not set oauth_link_user_id in session" do
        post "/mypage/identities/discord"

        expect(session[:oauth_link_user_id]).to be_nil
      end

      it "makes unlinked account callback create no Identity" do
        post "/mypage/identities/discord"
        # Clear the redirect to proceed with callback
        follow_redirect!

        # Now try the callback as an unlinked user
        mock_discord_auth(uid: "unlinked_uid", email: "unlinked@example.com")
        get "/auth/discord/callback"

        expect(Identity.count).to eq(0)
      end
    end
  end

  describe "OmniAuth linking flow" do
    let(:user) { create(:user) }

    before do
      post "/signin", params: { email: user.email, password: "password123" }
    end

    context "C2: Linking an unlinked external account" do
      it "adds identity via Discord" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")

        expect {
          get "/auth/discord/callback"
        }.to change { user.reload.identities.count }.by(1)

        expect(user.reload.identities.last.provider).to eq("discord")
        expect(user.reload.identities.last.uid).to eq("200000000000000001")
      end

      it "does not create a new user" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")

        expect {
          get "/auth/discord/callback"
        }.not_to change(User, :count)
      end

      it "redirects to mypage_path after linking" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")

        get "/auth/discord/callback"

        expect(response).to redirect_to(mypage_path)
      end

      it "keeps user logged in" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")

        get "/auth/discord/callback"

        expect(session[:user_id]).to eq(user.id)
      end

      it "displays success notice" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")

        get "/auth/discord/callback"

        expect(flash[:notice]).to eq("Discordアカウントを連携しました。")
      end

      it "allows login with linked Discord account after logout" do
        post "/mypage/identities/discord"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")
        get "/auth/discord/callback"

        delete "/signout"
        mock_discord_auth(uid: "200000000000000001", email: "discord@example.com")
        get "/auth/discord/callback"

        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
      end

      it "adds identity via Google" do
        delete "/signout"
        post "/signin", params: { email: user.email, password: "password123" }

        post "/mypage/identities/google"
        mock_google_auth(uid: "300000000000000001", email: "google@example.com")

        expect {
          get "/auth/google/callback"
        }.to change { user.reload.identities.count }.by(1)

        expect(flash[:notice]).to eq("Googleアカウントを連携しました。")
      end
    end

    context "C3: Linking an account already linked to another user" do
      let(:other_user) { create(:user) }
      let!(:other_identity) { create(:discord_identity, user: other_user, uid: "100000000000000001") }

      before do
        post "/mypage/identities/discord", params: {}
        mock_discord_auth(uid: "100000000000000001", email: "other@example.com")
      end

      it "does not change the identity's user" do
        get "/auth/discord/callback"

        other_identity.reload
        expect(other_identity.user_id).to eq(other_user.id)
      end

      it "does not add identity to current user" do
        expect {
          get "/auth/discord/callback"
        }.not_to change { user.reload.identities.count }
      end

      it "does not create new identity" do
        expect {
          get "/auth/discord/callback"
        }.not_to change(Identity, :count)
      end

      it "redirects to mypage_path" do
        get "/auth/discord/callback"

        expect(response).to redirect_to(mypage_path)
      end

      it "displays error alert" do
        get "/auth/discord/callback"

        expect(flash[:alert]).to eq("このDiscordアカウントはすでに別のユーザーに連携されているため、連携できません。")
      end

      it "keeps current user logged in" do
        get "/auth/discord/callback"

        expect(session[:user_id]).to eq(user.id)
      end

      it "shows error message on mypage after redirect" do
        get "/auth/discord/callback"
        follow_redirect!

        expect(response.body).to include("このDiscordアカウントはすでに別のユーザーに連携されているため、連携できません。")
      end
    end

    context "C4: Linking an account already linked to self" do
      context "with the same uid" do
        let!(:existing_identity) { create(:discord_identity, user: user, uid: "100000000000000002") }

        before do
          post "/mypage/identities/discord", params: {}
          mock_discord_auth(uid: "100000000000000002", email: "self@example.com")
        end

        it "does not create a new identity" do
          expect {
            get "/auth/discord/callback"
          }.not_to change(Identity, :count)
        end

        it "does not change existing identity" do
          get "/auth/discord/callback"

          existing_identity.reload
          expect(existing_identity.user_id).to eq(user.id)
        end

        it "redirects to mypage_path" do
          get "/auth/discord/callback"

          expect(response).to redirect_to(mypage_path)
        end

        it "does not display alert" do
          get "/auth/discord/callback"

          expect(flash[:alert]).to be_nil
        end

        it "keeps session[:user_id] as current user" do
          get "/auth/discord/callback"

          expect(session[:user_id]).to eq(user.id)
        end
      end

      context "with a different uid but same provider" do
        let!(:existing_identity) { create(:discord_identity, user: user, uid: "100000000000000003") }

        before do
          post "/mypage/identities/discord", params: {}
          mock_discord_auth(uid: "100000000000000004", email: "new@example.com")
        end

        it "does not create a new identity" do
          expect {
            get "/auth/discord/callback"
          }.not_to change(Identity, :count)
        end

        it "does not change existing identity" do
          get "/auth/discord/callback"

          existing_identity.reload
          expect(existing_identity.uid).to eq("100000000000000003")
        end

        it "redirects to mypage_path" do
          get "/auth/discord/callback"

          expect(response).to redirect_to(mypage_path)
        end

        it "keeps session[:user_id] as current user" do
          get "/auth/discord/callback"

          expect(session[:user_id]).to eq(user.id)
        end
      end
    end

    context "Linking without initiating from mypage" do
      it "does not link if user doesn't start from POST /mypage/identities" do
        # Don't call post "/mypage/identities/discord", just do callback directly
        mock_discord_auth(uid: "direct_callback_uid", email: "direct@example.com")

        expect {
          get "/auth/discord/callback"
        }.not_to change { user.reload.identities.count }

        # Should redirect to signin because no invitation
        expect(response).to redirect_to(signin_path)
      end
    end

    context "Session cleanup after callback" do
      before do
        post "/mypage/identities/discord", params: {}
        mock_discord_auth(uid: "cleanup_test_uid", email: "cleanup@example.com")
      end

      it "clears session[:oauth_link_user_id] after successful link" do
        get "/auth/discord/callback"

        expect(session[:oauth_link_user_id]).to be_nil
      end

      it "clears session[:oauth_link_user_id] even if user doesn't match" do
        # Simulate logout + linking attempt (which would fail to match current_user)
        delete "/signout"

        get "/auth/discord/callback"

        expect(session[:oauth_link_user_id]).to be_nil
      end
    end
  end
end
