require "rails_helper"

RSpec.describe "Admin Audit Logs", type: :system do
  let(:admin) { create(:user, :admin, username: "adminuser") }

  describe "モバイル幅での表示" do
    before do
      resize_window_to(390, 667)
      sign_in admin
      create(:audit_log, request_id: "req-mobile-test")
      visit admin_audit_logs_path
    end

    it "操作者・詳細・request_id の列が非表示になる" do
      page.find("th", text: "日時", visible: :visible)
      page.find("th", text: "操作", visible: :visible)
      page.find("th", text: "対象", visible: :visible)
      page.find("th", text: "結果", visible: :visible)

      expect(page).to have_css("th", text: "操作者", visible: :hidden)
      expect(page).to have_css("th", text: "詳細", visible: :hidden)
      expect(page).to have_css("th", text: "request_id", visible: :hidden)
    end
  end

  describe "デスクトップ幅での表示" do
    before do
      resize_window_to(1280, 1024)
      sign_in admin
      create(:audit_log, request_id: "req-desktop-test")
      visit admin_audit_logs_path
    end

    it "すべての列が表示される" do
      expect(page).to have_css("th", text: "日時", visible: :visible)
      expect(page).to have_css("th", text: "操作者", visible: :visible)
      expect(page).to have_css("th", text: "操作", visible: :visible)
      expect(page).to have_css("th", text: "対象", visible: :visible)
      expect(page).to have_css("th", text: "結果", visible: :visible)
      expect(page).to have_css("th", text: "詳細", visible: :visible)
      expect(page).to have_css("th", text: "request_id", visible: :visible)
    end
  end

  describe "管理メニューのリンク" do
    before do
      sign_in admin
    end

    it "デスクトップ幅で PC ナビの「監査ログ」をクリックすると admin_audit_logs_path に遷移する" do
      resize_window_to(1280, 1024)
      visit root_path

      click_link("監査ログ")

      expect(page).to have_current_path(admin_audit_logs_path)
    end

    it "モバイル幅でハンバーガーメニューの「監査ログ」をクリックすると admin_audit_logs_path に遷移する" do
      resize_window_to(390, 667)
      visit root_path

      hamburger_button = find("[data-hamburger-menu-target='icon']")
      hamburger_button.click

      drawer = find("[data-hamburger-menu-target='drawer']", visible: :visible)
      drawer.find("a", text: "監査ログ").click

      expect(page).to have_current_path(admin_audit_logs_path)
    end
  end
end
