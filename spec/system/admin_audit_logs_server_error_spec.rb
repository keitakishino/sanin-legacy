require "rails_helper"

RSpec.describe "Admin Audit Logs - Server Error Details", type: :system do
  let(:admin) { create(:user, :admin, username: "adminuser") }

  before do
    resize_window_to(1280, 1024)
    sign_in admin
  end

  describe "500 エラー行の表示" do
    let(:log) do
      create(:audit_log,
        user: nil,
        action: "system.error",
        result: :failure,
        target_type: nil,
        target_id: nil,
        status_code: 500,
        request_id: "req-500",
        details: {
          "reason" => "RuntimeError: outer boom",
          "error_class" => "RuntimeError",
          "message" => "outer boom",
          "backtrace" => "app/controllers/foo_controller.rb:10:in 'show'\napp/controllers/bar.rb:20",
          "causes" => [],
          "path" => "/foo/1",
          "http_method" => "GET"
        }
      )
    end

    before do
      log
      visit admin_audit_logs_path
    end

    it "既定は閉じていて、summary に reason が出る" do
      row = find("tr[data-audit-log-id='#{log.id}']")
      expect(row).to have_css("details.audit-log-server-error:not([open])")
      summary = row.find("summary")
      expect(summary.text).to include("RuntimeError: outer boom")
      expect(row).to have_css("pre.audit-log-backtrace", visible: :hidden)
      expect(row.text).not_to include("app/controllers/foo_controller.rb:10")
    end

    it "summary をクリックすると error_class・message・バックトレース・path・http_method が見える" do
      row = find("tr[data-audit-log-id='#{log.id}']")
      row.find("summary").click
      expect(row).to have_css("details.audit-log-server-error[open]")
      expect(row.text).to include("RuntimeError")
      expect(row.text).to include("outer boom")
      expect(row).to have_css("pre.audit-log-backtrace", text: "app/controllers/foo_controller.rb:10", visible: :visible)
      expect(row.text).to include("/foo/1")
      expect(row.text).to include("GET")
      expect(row.text).to include("サーバーエラー")
      expect(row.all("td")[3].text).to include("－")
    end
  end
end
