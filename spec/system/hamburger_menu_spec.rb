# NOTE: このテストはSelenium/ChromeDriver環境が整備されるまでCI実行対象から除外されています。
# 開発環境で `rspec spec/system/hamburger_menu_spec.rb` で手動実行可能。
# TODO: CI環境にChrome/Selenium サービスを追加したら、.rspec から除外パターンを削除

require "rails_helper"

RSpec.describe "Hamburger Menu", type: :system do
  let(:user) { create(:user, username: "testuser") }
  let(:admin) { create(:user, :admin, username: "adminuser") }

  describe "デスクトップ表示（md以上）" do
    before do
      driven_by(:selenium_chrome) do |options|
        options.add_argument("--window-size=1280,1024")
      end
      sign_in user
      visit root_path
    end

    it "ハンバーガーメニューアイコンが非表示である" do
      header = find("header[data-controller='hamburger-menu']")
      hamburger_button = header.find("[data-hamburger-menu-target='icon']", visible: :all)
      expect(hamburger_button).not_to be_visible
    end

    it "デスクトップナビゲーションが表示されている" do
      nav = find("nav:not([data-hamburger-menu-target])")
      expect(nav).to be_visible
      expect(nav).to have_link("ダッシュボード")
      expect(nav).to have_link("イベント")
      expect(nav).to have_link("トレード履歴")
    end

    it "ドロワーメニューが非表示である" do
      drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
      expect(drawer).not_to be_visible
    end
  end

  describe "モバイル表示（md未満）" do
    before do
      driven_by(:selenium_chrome) do |options|
        options.add_argument("--window-size=390,667")
      end
    end

    context "一般ユーザーがサインイン時" do
      before do
        sign_in user
        visit root_path
      end

      it "ハンバーガーメニューアイコンが表示されている" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        expect(hamburger_button).to be_visible
      end

      it "デスクトップナビゲーションが非表示である" do
        nav = find("nav[aria-label]", visible: :all)
        expect(nav).not_to be_visible
      end

      it "初期状態ではドロワーメニューが閉じている" do
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
        expect(drawer).not_to be_visible
        expect(drawer).to have_attribute("aria-hidden", "true")
      end

      it "ハンバーガーボタンをクリックするとドロワーメニューが開く" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        hamburger_button.click

        expect(drawer).to be_visible
        expect(drawer).to have_attribute("aria-hidden", "false")
        expect(header).to have_attribute("aria-expanded", "true")
      end

      it "ドロワーメニューが開いている状態で、再度ボタンをクリックするとドロワーが閉じる" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        # Open the menu
        hamburger_button.click
        expect(drawer).to be_visible

        # Close the menu
        hamburger_button.click
        expect(drawer).not_to be_visible
        expect(drawer).to have_attribute("aria-hidden", "true")
      end

      it "ドロワー内のリンククリックでメニューが閉じる" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        # Open the menu
        hamburger_button.click
        expect(drawer).to be_visible

        # Click a link in the drawer
        events_link = drawer.find("a", text: "イベント")
        events_link.click

        # Drawer should be closed after navigation
        sleep 1
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
        expect(drawer).not_to be_visible
      end

      it "ドロワーメニューに一般ユーザー向けのナビゲーション項目が表示されている" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        hamburger_button.click

        expect(drawer).to have_link("ダッシュボード")
        expect(drawer).to have_link("イベント")
        expect(drawer).to have_link("トレード履歴")
        expect(drawer).to have_link("マイページ")
        expect(drawer).to have_button("Sign Out")
        expect(drawer).to have_content("testuser")
      end

      it "ドロワーメニューに管理者ロールバッジが表示されていない" do
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
        expect(drawer).not_to have_content("管理者")
      end
    end

    context "管理者がサインイン時" do
      before do
        sign_in admin
        visit root_path
      end

      it "ハンバーガーメニューアイコンが表示されている" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        expect(hamburger_button).to be_visible
      end

      it "ドロワーメニューに管理者向けのナビゲーション項目が表示されている" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        hamburger_button.click

        expect(drawer).to have_link("ダッシュボード")
        expect(drawer).to have_link("イベント管理")
        expect(drawer).to have_link("ユーザー管理")
        expect(drawer).to have_link("招待コード管理")
        expect(drawer).to have_link("マイページ")
        expect(drawer).to have_button("Sign Out")
        expect(drawer).to have_content("adminuser")
      end

      it "ドロワーメニューに管理者ロールバッジが表示されている" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']")
        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

        hamburger_button.click

        expect(drawer).to have_content("管理者")
      end
    end

    context "未サインイン時" do
      before do
        visit root_path
      end

      it "ハンバーガーメニューアイコンが表示されない" do
        header = find("header[data-controller='hamburger-menu']")
        hamburger_button = header.find("[data-hamburger-menu-target='icon']", visible: :all)
        expect(hamburger_button).not_to be_visible
      end

      it "Sign Inボタンが表示される" do
        expect(page).to have_link("Sign In")
      end
    end
  end

  describe "Escapeキーでメニュー閉じる" do
    before do
      driven_by(:selenium_chrome) do |options|
        options.add_argument("--window-size=390,667")
      end
      sign_in user
      visit root_path
    end

    it "メニューが開いている状態でEscapeキーを押すとメニューが閉じる" do
      header = find("header[data-controller='hamburger-menu']")
      hamburger_button = header.find("[data-hamburger-menu-target='icon']")
      drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

      # Open the menu
      hamburger_button.click
      expect(drawer).to be_visible

      # Press Escape key
      find("body").send_keys(:escape)
      sleep 0.5

      expect(drawer).not_to be_visible
      expect(drawer).to have_attribute("aria-hidden", "true")
    end
  end

  describe "ページ遷移後のメニュー状態リセット" do
    before do
      driven_by(:selenium_chrome) do |options|
        options.add_argument("--window-size=390,667")
      end
      sign_in user
      visit root_path
    end

    it "メニューを開いた状態で別ページに遷移するとメニューが閉じる" do
      header = find("header[data-controller='hamburger-menu']")
      hamburger_button = header.find("[data-hamburger-menu-target='icon']")
      drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)

      # Open the menu
      hamburger_button.click
      expect(drawer).to be_visible

      # Navigate to another page via a link
      find("header a", text: "イベント").click
      sleep 1

      # Drawer should be closed
      drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
      expect(drawer).not_to be_visible
      expect(drawer).to have_attribute("aria-hidden", "true")
    end
  end
end
