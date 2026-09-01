require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }

  describe "GET /admin/users" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get admin_users_path
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_users_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_users_path
        expect(response).to have_http_status(:ok)
      end

      it "displays all users" do
        create_list(:user, 3)
        get admin_users_path
        expect(response.body).to include("ユーザー管理")
      end

      it "displays users in reverse chronological order" do
        user1 = create(:user, username: "user1", created_at: 1.day.ago)
        user2 = create(:user, username: "user2", created_at: Time.current)

        get admin_users_path
        body = response.body

        pos1 = body.index(user1.username)
        pos2 = body.index(user2.username)

        expect(pos2).to be < pos1
      end

      context "with search parameter" do
        it "filters users by username" do
          user1 = create(:user, username: "john_doe")
          user2 = create(:user, username: "jane_smith")

          get admin_users_path, params: { q: "john" }
          expect(response.body).to include(user1.username)
          expect(response.body).not_to include(user2.username)
        end

        it "filters users by email" do
          user1 = create(:user, email: "john@example.com")
          user2 = create(:user, email: "jane@example.com")

          get admin_users_path, params: { q: "john@" }
          expect(response.body).to include(user1.username)
          expect(response.body).not_to include(user2.username)
        end

        it "performs case-insensitive search" do
          user = create(:user, username: "JohnDoe", email: "john@example.com")

          get admin_users_path, params: { q: "johndoe" }
          expect(response.body).to include(user.username)
        end

        it "returns empty result when no users match" do
          create(:user, username: "test_user")

          get admin_users_path, params: { q: "nonexistent" }
          expect(response.body).to include("ユーザーはまだ登録されていません")
        end
      end

      context "with turbo_stream request" do
        it "responds with turbo_stream" do
          get admin_users_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include("text/vnd.turbo-stream.html")
        end

        it "updates users_list frame" do
          get admin_users_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response.body).to include('target="users_list"')
        end
      end
    end
  end

  describe "GET /admin/users/:id" do
    let(:user) { create(:user, email: "test@example.com") }

    context "when user is not logged in" do
      it "redirects to sign in path" do
        get admin_user_path(user)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_user_path(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_user_path(user)
        expect(response).to have_http_status(:ok)
      end

      it "displays user registration information" do
        get admin_user_path(user)
        expect(response.body).to include(user.username)
        expect(response.body).to include(user.email)
        expect(response.body).to include("登録情報")
      end

      it "displays user role" do
        get admin_user_path(user)
        expect(response.body).to include("一般ユーザー")
      end

      it "displays admin role label for admin users" do
        admin = create(:admin_user)
        get admin_user_path(admin)
        expect(response.body).to include("管理者")
      end

      context "with external account identities" do
        it "displays external accounts section" do
          get admin_user_path(user)
          expect(response.body).to include("外部アカウント連携")
        end

        it "displays google identity" do
          create(:identity, user: user, provider: :google, uid: "google123")
          get admin_user_path(user)
          expect(response.body).to include("Google")
          expect(response.body).to include("google123")
        end

        it "displays twitter identity with link" do
          twitter_identity = create(:identity, user: user, provider: :twitter, uid: "123456")
          get admin_user_path(user)
          expect(response.body).to include("Twitter(X)")
          expect(response.body).to include(twitter_identity.twitter_profile_url)
        end

        it "displays no external accounts message when empty" do
          get admin_user_path(user)
          expect(response.body).to include("外部アカウント連携がありません")
        end
      end

      context "with trades" do
        it "displays trades section" do
          create(:trade, user: user)
          get admin_user_path(user)
          expect(response.body).to include("トレード一覧")
        end

        it "displays trades in reverse chronological order" do
          event1 = create(:event, title: "Event 1")
          event2 = create(:event, title: "Event 2")
          trade1 = create(:trade, user: user, event: event1, created_at: 1.day.ago)
          trade2 = create(:trade, user: user, event: event2, created_at: Time.current)

          get admin_user_path(user)
          body = response.body

          pos1 = body.index(trade1.event.title)
          pos2 = body.index(trade2.event.title)

          expect(response.body).to include(trade1.event.title)
          expect(response.body).to include(trade2.event.title)
          # Newer trade should appear before older trade in reverse chronological order
          expect(pos2).to be < pos1
        end

        it "displays event title for each trade" do
          event = create(:event, title: "Test Event")
          create(:trade, user: user, event: event)
          get admin_user_path(user)
          expect(response.body).to include("Test Event")
        end

        it "displays trade status" do
          event = create(:event)
          trade = create(:trade, user: user, event: event, status: :in_progress)
          get admin_user_path(user)
          expect(response.body).to include("進行中")
        end

        it "displays no trades message when empty" do
          get admin_user_path(user)
          expect(response.body).to include("トレード履歴はありません")
        end
      end
    end
  end

  describe "Admin navigation link" do
    context "when admin is logged in" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "shows user management link in navigation" do
        get root_path
        expect(response.body).to include("ユーザー管理")
        expect(response.body).to include(admin_users_path)
      end

      it "shows invitation management link in navigation" do
        get root_path
        expect(response.body).to include("招待コード管理")
        expect(response.body).to include(admin_invitations_path)
      end
    end

    context "when general user is logged in" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "does not show admin links in navigation" do
        get root_path
        expect(response.body).not_to include("ユーザー管理")
        expect(response.body).not_to include("招待コード管理")
      end
    end

    context "when user is not logged in" do
      it "does not show admin links in navigation" do
        get root_path
        expect(response.body).not_to include("ユーザー管理")
        expect(response.body).not_to include("招待コード管理")
      end
    end
  end
end
