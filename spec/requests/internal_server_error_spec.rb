require "rails_helper"

RSpec.describe "500 Internal Server Error (Issue #418)", type: :request do
  around do |example|
    # テスト環境で DebugExceptions がデバッグ画面を出さないようにする
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    example.run

    Rails.application.env_config["action_dispatch.show_exceptions"] = :rescuable
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = true
  end

  describe "C1: 500 error shows dynamic error layout" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "returns 500 with error layout when action raises exception" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      get "/events"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("サーバーエラーが発生しました")
      expect(response.body).to include("しばらくしてからもう一度お試しください")
      expect(response.body).to include("500")
      expect(response.body).to include(root_path)
      # error レイアウト確認: header タグを含まない
      expect(response.body).not_to include("<header")
      # 静的ページではないことを確認
      expect(response.body).not_to eq(File.read(Rails.public_path.join("500.html")))
    end
  end

  describe "C2: 500 error is recorded in audit log" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "records audit log with action system.error and status_code 500" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      expect do
        get "/events"
      end.to change { AuditLog.count }.by(1)

      log = AuditLog.last
      expect(log.action).to eq("system.error")
      expect(log.result_failure?).to be true
      expect(log.status_code).to eq(500)
      expect(log.request_id).to eq(response.headers["X-Request-Id"])
    end
  end

  describe "C3: 500 error records user_id from session" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "records user_id when logged in" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      expect do
        get "/events"
      end.to change { AuditLog.count }.by(1)

      log = AuditLog.last
      expect(log.user_id).to eq(user.id)
    end

    it "records user_id as nil when not logged in" do
      # ログアウト
      delete "/signout"
      Capybara.reset_sessions!

      allow_any_instance_of(SessionsController).to receive(:new).and_raise(RuntimeError, "boom")

      expect do
        get "/signin"
      end.to change { AuditLog.count }.by(1)

      log = AuditLog.last
      expect(log.user_id).to be_nil
      # ボタンのリンク先が signin_path であることを確認
      expect(response.body).to include(signin_path)
    end
  end

  describe "C4: 500 error details contain exception information" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "records exception details with class, message, backtrace, causes, path, and http_method" do
      # cause つき例外を構築
      inner_error = ArgumentError.new("inner error")
      outer_error = RuntimeError.new("outer error")
      allow(outer_error).to receive(:cause).and_return(inner_error)

      allow_any_instance_of(Admin::EventsController).to receive(:index).and_raise(outer_error)

      get "/admin/events"

      log = AuditLog.last
      details = log.details

      expect(details["error_class"]).to eq("RuntimeError")
      expect(details["message"]).to include("outer error")
      expect(details["reason"]).to include("RuntimeError: outer error")
      expect(details["backtrace"]).to be_a(String)
      expect(details["causes"]).to be_an(Array)
      expect(details["causes"][0]["error_class"]).to eq("ArgumentError")
      expect(details["path"]).to start_with("/admin/events")
      expect(details["path"]).not_to include("/500")
      expect(details["http_method"]).to eq("GET")
    end

    it "filters sensitive query parameters from path" do
      allow_any_instance_of(Admin::EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      get "/admin/events", params: { token: "secret123" }

      log = AuditLog.last
      details = log.details
      expect(details["path"]).not_to include("secret123")
    end

    it "records PATCH request http_method" do
      event = create(:event, created_by: admin)
      allow_any_instance_of(Admin::EventsController).to receive(:update).and_raise(RuntimeError, "boom")

      patch admin_event_path(event), params: { event: { title: "Updated" } }

      log = AuditLog.last
      details = log.details
      expect(details["http_method"]).to eq("PATCH")
    end
  end

  describe "C5: to_line method formats backtrace lines" do
    it "outputs only reason for logs with backtrace" do
      log = AuditLog.create!(
        action: "system.error",
        result: :failure,
        status_code: 500,
        details: {
          "reason" => "RuntimeError: boom",
          "error_class" => "RuntimeError",
          "backtrace" => "app/foo.rb:1\napp/bar.rb:2",
          "causes" => []
        }
      )

      line = log.to_line
      expect(line).to include("理由: RuntimeError: boom")
      expect(line).not_to include("app/foo.rb")
      expect(line).not_to include("details=")
    end

    it "does not include backtrace content in line when error_class is used as reason" do
      log = AuditLog.create!(
        action: "system.error",
        result: :failure,
        status_code: 500,
        details: {
          "error_class" => "RuntimeError",
          "backtrace" => "app/foo.rb:1"
        }
      )

      line = log.to_line
      expect(line).not_to include("app/foo.rb")
      expect(line).not_to include("details=")
    end
  end

  describe "C6: 500 error is returned even when audit log recording fails" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "returns 500 page even when AuditLog.record! raises exception" do
      allow(AuditLog).to receive(:record!).and_raise(ActiveRecord::ConnectionNotEstablished, "DB connection lost")

      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      get "/events"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("サーバーエラーが発生しました")
    end
  end

  describe "C7: fallback to static page when render fails" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "returns static 500 page when ErrorsController fails to render" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "original error")
      allow_any_instance_of(ErrorsController).to receive(:render).and_raise(RuntimeError, "render failed")

      get "/events"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.content_type).to include("text/html")
      expect(response.body).to eq(File.read(Rails.public_path.join("500.html")))
      expect(response.body).not_to include("If you are the administrator")
    end
  end

  describe "C10: audit record timeout does not delay 500 response" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "returns 500 page within timeout when audit recording is slow" do
      stub_const("ErrorsController::AUDIT_TIMEOUT_SECONDS", 0.2)
      allow(AuditLog).to receive(:record!) { sleep 2 }

      allow_any_instance_of(EventsController).to receive(:index).and_raise(RuntimeError, "boom")

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get "/events"
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("サーバーエラーが発生しました")
      # タイムアウト + レスポンス生成で1秒以内
      expect(elapsed).to be < 1
    end
  end
end
