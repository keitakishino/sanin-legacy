require "rails_helper"

RSpec.describe "サインイン画面の外部アカウントボタン", type: :system do
  before do
    visit signin_path
  end

  after do
    clear_omniauth_mocks
  end

  describe "C1: ボタンの表示と連携済みDiscordでのログイン" do
    it "サインイン画面にGoogleボタンとDiscordボタンが表示される" do
      expect(page).to have_button("Google でサインイン")
      expect(page).to have_button("Discord でサインイン")
      expect(page).to have_selector('form[action="/auth/google"]')
      expect(page).to have_selector('form[action="/auth/discord"]')
    end

    it "連携済みのDiscordアカウントでサインインできる" do
      user = create(:user)
      create(:identity, user: user, provider: :discord, uid: "80351110224678912")
      mock_discord_auth(uid: "80351110224678912")

      click_button "Discord でサインイン"

      expect(page).to have_text("ダッシュボード")
      expect(page).not_to have_link("Sign In")
    end
  end

  describe "C2: 連携済みGoogleでのログイン" do
    it "連携済みのGoogleアカウントでサインインできる" do
      user = create(:user)
      create(:identity, user: user, provider: :google, uid: "123456789")
      mock_google_auth(uid: "123456789")

      click_button "Google でサインイン"

      expect(page).to have_text("ダッシュボード")
    end
  end

  describe "C3: 未連携アカウントのメッセージ表示" do
    it "未連携のDiscordアカウントでは招待コード必須メッセージが表示される" do
      mock_discord_auth(uid: "999999999999")

      expect do
        click_button "Discord でサインイン"
        expect(page).to have_text("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end.not_to change(User, :count)

      expect(page).to have_current_path(signin_path)
      expect(Identity.count).to eq(0)
    end

    it "未連携のGoogleアカウントでは招待コード必須メッセージが表示される" do
      mock_google_auth(uid: "000000001")

      expect do
        click_button "Google でサインイン"
        expect(page).to have_text("未登録の外部アカウントです。招待コードを入力して登録してください。")
      end.not_to change(User, :count)

      expect(page).to have_current_path(signin_path)
      expect(Identity.count).to eq(0)
    end
  end
end
