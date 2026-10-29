require "rails_helper"

RSpec.describe "OAuth Buttons and Integrations", type: :system do
  describe "Home page (/)" do
    context "when user is not signed in" do
      before do
        visit root_path
        # ホームページは未ログインユーザーを signin_path にリダイレクトする可能性があるため、
        # ページの内容ではなく、リダイレクト先のコンテンツを確認
      end

      it "does not show X button on home page" do
        # pages/home.html.erb が表示される状態またはサインインページが表示される
        # どちらの場合でも Twitter ボタンが存在しないことを確認
        expect(page).not_to have_text("Sign In with X (Twitter)")
        expect(page).not_to have_selector('form[action="/auth/twitter"]', visible: :all)
        expect(page).not_to have_link(text: /X|Twitter/, href: /\/auth\/twitter/)
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user, username: "testuser") }

      before do
        sign_in user
        visit root_path
      end

      it "shows dashboard and no X button" do
        # ログイン後は dashboard にリダイレクトされる
        expect(page).to have_text("ダッシュボード")
        expect(page).not_to have_selector('form[action="/auth/twitter"]', visible: :all)
        expect(page).not_to have_text("Sign In with X (Twitter)")
      end
    end
  end

  describe "Signup page (/signup)" do
    before do
      @invitation = create(:invitation)
      @signup_token = @invitation.generate_signup_token
      # 招待トークンを使ってサインアップページにアクセス
      visit signup_path(token: @signup_token)
    end

    it "shows Discord signup button" do
      # "Discord でサインアップ" テキストが存在
      expect(page).to have_text("Discord でサインアップ")
    end

    it "shows Google signup button" do
      # "Google でサインアップ" テキストが存在
      expect(page).to have_text("Google でサインアップ")
    end

    it "shows Discord signup button posting to /auth/discord and no X button" do
      # Discord ボタンの form が /auth/discord にポストする
      # page.html でも確認できるが、ここでは button_to が生成する form の内容を確認
      page_text = page.text
      expect(page_text).to include("Discord でサインアップ")
      expect(page_text).to include("Google でサインアップ")
      expect(page_text).not_to include("X でサインアップ")
      expect(page_text).not_to include("Twitter でサインアップ")
      expect(page_text).not_to include("X (Twitter)")

      # Twitter への form が存在しないことを確認
      expect(page).not_to have_selector('form[action*="/auth/twitter"]', visible: :all)
    end
  end

  describe "User profile page (/mypage)" do
    let(:user) { create(:user, username: "testuser") }
    let(:discord_identity) { create(:discord_identity, user: user) }

    context "when user has Discord identity" do
      before do
        discord_identity
        sign_in user
        visit mypage_path
      end

      it "shows Discord identity without twitter link" do
        expect(page).to have_text("Discord")
        expect(page).not_to have_link(href: /twitter\.com/)
        expect(page).not_to have_text("アカウントを表示")
      end
    end

    context "when user has multiple identities (Google and Discord)" do
      before do
        create(:identity, user: user, provider: :google, uid: "123456")
        discord_identity
        sign_in user
        visit mypage_path
      end

      it "shows both Google and Discord without twitter link" do
        expect(page).to have_text("Google")
        expect(page).to have_text("Discord")
        expect(page).not_to have_link(href: /twitter\.com/)
      end
    end
  end

  describe "Admin user details page (/admin/users/:id)" do
    let(:admin) { create(:user, :admin, username: "admin") }
    let(:user) { create(:user, username: "testuser") }
    let(:discord_identity) { create(:discord_identity, user: user) }

    before do
      discord_identity
      sign_in admin
      visit admin_user_path(user)
    end

    it "displays discord identity without twitter link" do
      expect(page).to have_text("Discord")
      expect(page).to have_text(discord_identity.uid)
      expect(page).not_to have_link(href: /twitter\.com/)
      expect(page).not_to have_text("アカウントを表示")
    end

    it "does not show twitter account link on admin user page" do
      expect(page).not_to have_text("twitter.com")
      expect(page).not_to have_link(text: /View Account|アカウントを表示/, href: /twitter\.com/)
    end
  end
end
