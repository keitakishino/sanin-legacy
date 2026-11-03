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

    it "500 エラー行でも詳細列が非表示になる" do
      create(:audit_log,
        user: nil,
        action: "system.error",
        result: :failure,
        target_type: nil,
        target_id: nil,
        status_code: 500,
        request_id: "req-mobile-error",
        details: {
          "reason" => "RuntimeError: error",
          "error_class" => "RuntimeError",
          "message" => "error",
          "backtrace" => "app/controllers/foo.rb:10",
          "causes" => [],
          "path" => "/foo/1",
          "http_method" => "GET"
        }
      )
      visit admin_audit_logs_path
      expect(page).to have_css("th", text: "詳細", visible: :hidden)
      expect(page).to have_css("details.audit-log-server-error", visible: :hidden)
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

  describe "通常の行の詳細列" do
    before do
      resize_window_to(1280, 1024)
      sign_in admin
    end

    it "reason がある失敗の行は reason をそのまま表示する" do
      log = create(:audit_log,
        details: { "reason" => "イベント日時 は過去の日付に設定することはできません" },
        result: :failure
      )
      visit admin_audit_logs_path
      row = find("tr[data-audit-log-id='#{log.id}']")
      details_cell = row.all("td")[5]
      expect(details_cell.text).to include("イベント日時 は過去の日付に設定することはできません")
      expect(details_cell.all("details")).to be_empty
      expect(details_cell["title"]).to eq("イベント日時 は過去の日付に設定することはできません")
    end

    it "reason がない行は JSON を truncate して表示する" do
      log = create(:audit_log,
        details: { "foo" => "bar" * 30 },
        result: :success
      )
      visit admin_audit_logs_path
      row = find("tr[data-audit-log-id='#{log.id}']")
      details_cell = row.all("td")[5]
      json_str = { "foo" => "bar" * 30 }.to_json
      expected_text = json_str[0...57] + "..."
      expect(details_cell.text).to include(expected_text[0...30])
      expect(details_cell.all("details")).to be_empty
      expect(details_cell["title"]).to eq(json_str)
    end

    it "details が空の行は「－」を表示する" do
      log = create(:audit_log, details: {})
      visit admin_audit_logs_path
      row = find("tr[data-audit-log-id='#{log.id}']")
      details_cell = row.all("td")[5]
      expect(details_cell.text).to include("－")
      expect(details_cell.all("details")).to be_empty
    end

    it "詳細行に details 要素がない" do
      create(:audit_log)
      create(:audit_log, details: { "reason" => "test" })
      visit admin_audit_logs_path
      expect(page).not_to have_css("details.audit-log-server-error")
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
