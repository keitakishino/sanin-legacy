require "rails_helper"

RSpec.describe "Admin Audit Logs - Server Error Causes", type: :system do
  let(:admin) { create(:user, :admin, username: "adminuser") }

  before do
    resize_window_to(1280, 1024)
    sign_in admin
  end

  describe "causes の表示" do
    let(:log) do
      create(:audit_log,
        user: nil,
        action: "system.error",
        result: :failure,
        target_type: nil,
        target_id: nil,
        status_code: 500,
        request_id: "req-causes",
        details: {
          "reason" => "RuntimeError: outer boom",
          "error_class" => "RuntimeError",
          "message" => "outer boom",
          "backtrace" => "app/controllers/foo_controller.rb:10:in 'show'",
          "causes" => [
            {
              "error_class" => "ArgumentError",
              "message" => "inner one",
              "backtrace" => "app/models/one.rb:1"
            },
            {
              "error_class" => "KeyError",
              "message" => "inner two",
              "backtrace" => "app/models/two.rb:2"
            }
          ],
          "path" => "/foo/1",
          "http_method" => "GET"
        }
      )
    end

    before do
      log
      visit admin_audit_logs_path
    end

    it "summary をクリックすると原因1・原因2 と詳細が見える" do
      row = find("tr[data-audit-log-id='#{log.id}']")
      row.find("summary").click
      expect(row).to have_css("details.audit-log-server-error[open]")
      expect(row.text).to include("原因1")
      expect(row.text).to include("原因2")
      expect(row.text).to include("ArgumentError")
      expect(row.text).to include("inner one")
      expect(row.text).to include("KeyError")
      expect(row.text).to include("inner two")
      expect(row).to have_css("pre.audit-log-backtrace", text: "app/models/one.rb:1", visible: :visible)
      expect(row).to have_css("pre.audit-log-backtrace", text: "app/models/two.rb:2", visible: :visible)
    end

    it "並び順が正しい（本体 > 原因1 > 原因2 > path）" do
      row = find("tr[data-audit-log-id='#{log.id}']")
      row.find("summary").click
      text = row.text
      outer_index = text.index("app/controllers/foo_controller.rb:10")
      cause1_index = text.index("原因1")
      cause2_index = text.index("原因2")
      path_index = text.index("/foo/1")
      expect(outer_index).to be < cause1_index
      expect(cause1_index).to be < cause2_index
      expect(cause2_index).to be < path_index
    end
  end
end
