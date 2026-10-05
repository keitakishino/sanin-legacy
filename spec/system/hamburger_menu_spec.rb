require "rails_helper"

RSpec.describe "Hamburger Menu", type: :system do
  let(:user) { create(:user, username: "testuser") }
  let(:admin) { create(:user, :admin, username: "adminuser") }

  describe "デスクトップ表示（md以上）" do
    before do
      resize_window_to(1280, 1024)
      sign_in user
      visit root_path
    end

    it "ハンバーガーメニューアイコンが非表示である" do
      expect(page).to have_css("[data-hamburger-menu-target='icon']", visible: :hidden)
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

    context "管理者がサインインしたとき" do
      before do
        sign_in admin
        visit root_path
      end

      it "PC ナビに「イベント管理」「ユーザー管理」「招待コード管理」のリンクがあり、「イベント管理」をクリックすると admin_events_path に移る" do
        nav = find("nav:not([data-hamburger-menu-target])")
        expect(nav).to have_link("イベント管理")
        expect(nav).to have_link("ユーザー管理")
        expect(nav).to have_link("招待コード管理")

        click_link("イベント管理")

        expect(page).to have_current_path(admin_events_path)
      end
    end
  end

  describe "モバイル表示（md未満）" do
    before do
      resize_window_to(390, 667)
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
        nav = find("header > div:first-child > nav", visible: :all)
        expect(nav).not_to be_visible
      end

      it "初期状態ではドロワーメニューが閉じている" do
        expect(page).to have_css("[data-hamburger-menu-target='drawer'][aria-hidden='true']", visible: :all)
      end

      it "ハンバーガーボタンをクリックするとドロワーメニューが開く" do
        hamburger_button = find("[data-hamburger-menu-target='icon']")
        hamburger_button.click

        expect(page).to have_css("[data-hamburger-menu-target='drawer'][aria-hidden='false']", visible: :visible)
        expect(page).to have_css("header[data-controller='hamburger-menu'][aria-expanded='true']")
      end

      it "ドロワーメニューが開いている状態で、再度ボタンをクリックするとドロワーが閉じる" do
        hamburger_button = find("[data-hamburger-menu-target='icon']")

        hamburger_button.click
        expect(page).to have_css("[data-hamburger-menu-target='drawer']", visible: :visible)

        hamburger_button.click
        expect(page).to have_css("[data-hamburger-menu-target='drawer'][aria-hidden='true']", visible: :all)
      end

      it "ドロワー内のリンククリックでメニューが閉じる" do
        hamburger_button = find("[data-hamburger-menu-target='icon']")

        hamburger_button.click
        expect(page).to have_css("[data-hamburger-menu-target='drawer']", visible: :visible)

        drawer = find("[data-hamburger-menu-target='drawer']", visible: :all)
        events_link = drawer.find("a", text: "イベント")
        events_link.click

        expect(page).to have_current_path(events_path)
        expect(page).to have_css("[data-hamburger-menu-target='drawer']", visible: :hidden)
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
        expect(page).to have_no_css("[data-hamburger-menu-target='icon']", visible: :all)
      end

      it "Sign Inボタンが表示される" do
        expect(page).to have_current_path(signin_path)
        expect(page).to have_button("サインイン")
      end
    end
  end

  describe "Escapeキーでメニュー閉じる" do
    before do
      resize_window_to(390, 667)
      sign_in user
      visit root_path
    end

    it "メニューが開いている状態でEscapeキーを押すとメニューが閉じる" do
      hamburger_button = find("[data-hamburger-menu-target='icon']")

      hamburger_button.click
      expect(page).to have_css("[data-hamburger-menu-target='drawer']", visible: :visible)

      find("body").send_keys(:escape)

      expect(page).to have_css("[data-hamburger-menu-target='drawer'][aria-hidden='true']", visible: :all)
    end
  end

  describe "ページ遷移後のメニュー状態リセット" do
    before do
      resize_window_to(390, 667)
      sign_in user
      visit root_path
    end

    it "メニューを開いた状態で別ページに遷移するとメニューが閉じる" do
      hamburger_button = find("[data-hamburger-menu-target='icon']")

      hamburger_button.click
      expect(page).to have_css("[data-hamburger-menu-target='drawer']", visible: :visible)

      find("header a", text: "イベント").click

      expect(page).to have_current_path(events_path)
      expect(page).to have_css("[data-hamburger-menu-target='drawer'][aria-hidden='true']", visible: :all)
    end
  end
end
