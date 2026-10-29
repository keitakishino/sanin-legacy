require "rails_helper"

RSpec.describe "Mypage Identity Linking", type: :system do
  after do
    clear_omniauth_mocks
  end

  describe "C1: Discord linking from mypage" do
    let(:user) { create(:user) }

    it "shows Discord link button and links after authorization" do
      sign_in user
      visit mypage_path

      within "#identity-discord" do
        expect(page).to have_button("Discordを連携する")
        expect(page).not_to have_text("連携済み")
      end

      mock_discord_auth(uid: "200000000000000001", global_name: "Discord表示名")

      within "#identity-discord" do
        click_button "Discordを連携する"
      end

      expect(current_path).to eq(mypage_path)
      expect(page).to have_text("Discordアカウントを連携しました。")

      within "#identity-discord" do
        expect(page).to have_text("連携済み")
        expect(page).not_to have_button("Discordを連携する")
      end

      expect(user.reload.identities.provider_discord.count).to eq(1)
    end
  end

  describe "C2: Google linking from mypage" do
    let(:user) { create(:user) }

    it "links Google and shows success message" do
      sign_in user
      visit mypage_path

      mock_google_auth(uid: "300000001", name: "Google表示名")

      within "#identity-google" do
        click_button "Googleを連携する"
      end

      expect(page).to have_text("Googleアカウントを連携しました。")
      expect(Identity.find_by(provider: :google, uid: "300000001").user).to eq(user)

      within "#identity-google" do
        expect(page).to have_text("連携済み")
      end
    end
  end

  describe "C3: Username display in mypage and admin page" do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }

    it "displays Discord username and no links" do
      sign_in user
      visit mypage_path

      mock_discord_auth(uid: "200000000000000001", global_name: "Discord表示名")

      within "#identity-discord" do
        click_button "Discordを連携する"
      end

      within "#identity-discord" do
        expect(page).to have_text("Discord表示名")
        expect(page).not_to have_selector("a")
      end

      Capybara.reset_sessions!
      sign_in admin
      visit admin_user_path(user)

      within "#external-accounts" do
        expect(page).to have_text("Discord:")
        expect(page).to have_text("Discord表示名")
        expect(page).not_to have_selector("a")
        expect(page).not_to have_text("200000000000000001")
      end
    end

    it "displays Google username and no links" do
      sign_in user
      visit mypage_path

      mock_google_auth(uid: "300000002", name: "Google表示名")

      within "#identity-google" do
        click_button "Googleを連携する"
      end

      within "#identity-google" do
        expect(page).to have_text("Google表示名")
        expect(page).not_to have_selector("a")
      end

      Capybara.reset_sessions!
      sign_in admin
      visit admin_user_path(user)

      within "#external-accounts" do
        expect(page).to have_text("Google:")
        expect(page).to have_text("Google表示名")
        expect(page).not_to have_selector("a")
        expect(page).not_to have_text("300000002")
      end
    end
  end

  describe "C4: Signing in with linked accounts" do
    let(:user) { create(:user) }

    it "allows signing in with linked Discord account" do
      sign_in user
      visit mypage_path

      mock_discord_auth(uid: "200000000000000001", global_name: "Discord表示名")

      within "#identity-discord" do
        click_button "Discordを連携する"
      end

      Capybara.reset_sessions!
      visit signin_path

      mock_discord_auth(uid: "200000000000000001", global_name: "Discord表示名")
      click_button "Discord でサインイン"

      expect(page).to have_text("ダッシュボード")
    end

    it "allows signing in with linked Google account" do
      sign_in user
      visit mypage_path

      mock_google_auth(uid: "300000001", name: "Google表示名")

      within "#identity-google" do
        click_button "Googleを連携する"
      end

      Capybara.reset_sessions!
      visit signin_path

      mock_google_auth(uid: "300000001", name: "Google表示名")
      click_button "Google でサインイン"

      expect(page).to have_text("ダッシュボード")
    end
  end

  describe "C6: Username nil handling" do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }

    it "displays badge without username when username is nil" do
      create(:discord_identity, user: user, username: nil)

      sign_in user
      visit mypage_path

      within "#identity-discord" do
        expect(page).to have_text("Discord")
        expect(page).to have_text("連携済み")
        expect(page).not_to have_button("Discordを連携する")
      end

      Capybara.reset_sessions!
      sign_in admin
      visit admin_user_path(user)

      within "#external-accounts" do
        expect(page).to have_text("Discord:")
        expect(page).not_to have_text(user.identities.find_by(provider: :discord).uid)
      end
    end
  end
end
