require "rails_helper"
require "nokogiri"

RSpec.describe "Audit Log Status Code", type: :request do
  let(:admin_user) { create(:admin_user) }

  before do
    post signin_path, params: { email: admin_user.email, password: "password123" }
  end

  describe "status_code recording and display" do
    let(:valid_event_params) do
      {
        event: {
          title: "New Event",
          description: "d",
          event_date: Date.today + 7.days
        }
      }
    end

    it "records status_code 302 for successful event creation" do
      expect {
        post admin_events_path, params: valid_event_params
      }.to change(Event, :count).by(1)

      log = AuditLog.where(action: "event.create").last
      expect(log.status_code).to eq(302)
    end

    it "displays status_code 302 as badge for successful creation" do
      post admin_events_path, params: valid_event_params
      get admin_audit_logs_path

      doc = Nokogiri::HTML(response.body)
      log = AuditLog.where(action: "event.create").last
      span = doc.css("tbody tr[data-audit-log-id='#{log.id}'] span.audit-log-status-code").first

      expect(span.text).to eq("302")
      expect(span["title"]).to eq("成功")
      expect(span["class"]).to include("text-stone-800")
      expect(doc.css("tbody tr[data-audit-log-id='#{log.id}'] span.audit-log-failure-badge")).to be_empty
    end

    it "records status_code 422 for validation failure" do
      expect {
        post admin_events_path, params: { event: { title: "", description: "d", event_date: Date.today + 7.days } }
      }.not_to change(Event, :count)

      log = AuditLog.where(action: "event.create", result: :failure).last
      expect(log.status_code).to eq(422)
    end

    it "displays status_code 422 as amber badge for validation failure" do
      post admin_events_path, params: { event: { title: "", description: "d", event_date: Date.today + 7.days } }
      get admin_audit_logs_path

      doc = Nokogiri::HTML(response.body)
      log = AuditLog.where(action: "event.create", result: :failure).last
      span = doc.css("tbody tr[data-audit-log-id='#{log.id}'] span.audit-log-status-code").first

      expect(span.text).to eq("422")
      expect(span["title"]).to eq("失敗")
      expect(span["class"]).to include("bg-amber-50")
      expect(span["class"]).to include("text-amber-700")
      expect(span["class"]).to include("audit-log-failure-badge")
    end

    it "displays status_code 500 as red badge" do
      log = create(:audit_log, result: :failure, status_code: 500)

      get admin_audit_logs_path
      doc = Nokogiri::HTML(response.body)

      span = doc.css("tbody tr[data-audit-log-id='#{log.id}'] span.audit-log-status-code").first
      expect(span.text).to eq("500")
      expect(span["class"]).to include("bg-red-50")
      expect(span["class"]).to include("text-red-700")
      expect(span["class"]).to include("audit-log-failure-badge")
    end

    it "handles status_code update failure gracefully" do
      allow(AuditLog).to receive(:apply_status_code).and_raise(ActiveRecord::StatementInvalid, "boom")

      expect {
        post admin_events_path, params: valid_event_params
      }.to change(Event, :count).by(1)

      expect(response).to redirect_to(admin_events_path)

      log = AuditLog.where(action: "event.create", result: :success).last
      expect(log).to be_present
      expect(log.status_code).to be_nil
    end

    it "handles status_code update failure for failed operations gracefully" do
      allow(AuditLog).to receive(:apply_status_code).and_raise(ActiveRecord::StatementInvalid, "boom")

      expect {
        post admin_events_path, params: { event: { title: "", description: "d", event_date: Date.today + 7.days } }
      }.not_to change(Event, :count)

      expect(response.status).to eq(422)

      log = AuditLog.where(action: "event.create", result: :failure).last
      expect(log).to be_present
      expect(log.status_code).to be_nil
    end
  end
end
