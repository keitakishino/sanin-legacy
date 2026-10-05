require "rails_helper"
require "nokogiri"

RSpec.describe "Admin::AuditLogs", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }

  describe "GET /admin/audit_logs" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get admin_audit_logs_path
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_audit_logs_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_audit_logs_path
        expect(response).to have_http_status(:ok)
      end

      it "displays audit logs in newest first order" do
        log1 = create(:audit_log, created_at: 2.days.ago)
        log2 = create(:audit_log, created_at: 1.day.ago)
        log3 = create(:audit_log, created_at: Time.current)

        get admin_audit_logs_path
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(3)
        expect(rows[0].attr("data-audit-log-id").to_i).to eq(log3.id)
        expect(rows[1].attr("data-audit-log-id").to_i).to eq(log2.id)
        expect(rows[2].attr("data-audit-log-id").to_i).to eq(log1.id)
      end

      it "filters by failure result" do
        success_log = create(:audit_log, result: :success)
        failure_log = create(:audit_log, result: :failure)

        get admin_audit_logs_path(result: "failure")
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(1)
        expect(rows.first.attr("data-audit-log-id").to_i).to eq(failure_log.id)
      end

      it "filters by target type" do
        event_log = create(:audit_log, target_type: "Event", target_id: 17)
        invitation_log = create(:audit_log, target_type: "Invitation", target_id: 5)

        get admin_audit_logs_path(target_type: "Invitation")
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(1)
        expect(rows.first.attr("data-audit-log-id").to_i).to eq(invitation_log.id)
      end

      it "filters by target id" do
        log1 = create(:audit_log, target_type: "Event", target_id: 17)
        log2 = create(:audit_log, target_type: "Event", target_id: 18)

        get admin_audit_logs_path(target_id: "17")
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(1)
        expect(rows.first.attr("data-audit-log-id").to_i).to eq(log1.id)
      end

      it "paginates audit logs with 50 per page" do
        create_list(:audit_log, 51)

        get admin_audit_logs_path
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(50)

        get admin_audit_logs_path(page: 2)
        doc = Nokogiri::HTML(response.body)
        rows = doc.css("tbody tr[data-audit-log-id]")

        expect(rows.length).to eq(1)
      end

      it "displays audit log details correctly" do
        log = create(
          :audit_log,
          created_at: Time.utc(2026, 10, 4, 1, 21),
          user: admin_user,
          action: "event.discard",
          target_type: "Event",
          target_id: 17,
          result: :failure,
          details: { "reason" => "開催日が過去" },
          request_id: "req-abc"
        )

        get admin_audit_logs_path
        body = response.body

        expect(body).to include("10/04 10:21")
        expect(body).to include("admin@example.com")
        expect(body).to include("イベント削除")
        expect(body).to include("Event#17")
        expect(body).to include("req-abc")
        expect(body).to include("開催日が過去")
      end

      it "displays failure badge for failed logs" do
        success_log = create(:audit_log, result: :success)
        failure_log = create(:audit_log, result: :failure)

        get admin_audit_logs_path
        doc = Nokogiri::HTML(response.body)

        failure_rows = doc.css("tbody tr[data-audit-log-id='#{failure_log.id}'] span.audit-log-failure-badge")
        success_rows = doc.css("tbody tr[data-audit-log-id='#{success_log.id}'] span.audit-log-failure-badge")

        expect(failure_rows.length).to eq(1)
        expect(failure_rows.text).to include("失敗")
        expect(success_rows.length).to eq(0)
      end

      it "displays deleted user text when user is deleted" do
        log = create(:audit_log, user_id: 999, user: nil, action: "event.create")

        get admin_audit_logs_path
        body = response.body

        expect(body).to include("削除済み (user #999)")
      end

      it "displays dash when user_id is nil" do
        log = create(:audit_log, user_id: nil, user: nil, action: "event.create")

        get admin_audit_logs_path
        body = response.body

        expect(body).to include("－")
      end
    end
  end
end
