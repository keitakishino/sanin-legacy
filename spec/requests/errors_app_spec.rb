require "rails_helper"

RSpec.describe "ErrorsApp (config.exceptions_app)", type: :request do
  around do |example|
    # テスト環境で DebugExceptions がデバッグ画面を出さないようにする
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    example.run

    Rails.application.env_config["action_dispatch.show_exceptions"] = :rescuable
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = true
  end

  describe "RecordNotFound renders the 404 page" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "returns 404 with error layout for non-existent admin event" do
      get edit_admin_event_path(999_999)

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("ページが見つかりません")
      expect(response.body).to include("見つかりませんでした")
      expect(response.body).to include(root_path)
      # error レイアウト確認: header タグを含まない
      expect(response.body).not_to include("<header")
    end

    it "returns 404 with error layout for non-existent trade event proxy order" do
      trade_event = create(:event, event_type: :trade, created_by: admin)
      get admin_event_proxy_order_path(trade_event)

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("ページが見つかりません")
    end

    it "returns 404 with error layout for non-existent proxy order" do
      general_user = create(:user, role: :general)
      post "/signin", params: { email: general_user.email, password: general_user.password }
      get proxy_order_path(999_999)

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("ページが見つかりません")
    end

    it "returns 404 for turbo_stream PATCH with non-existent record" do
      patch admin_event_path(999_999),
            params: { event: { title: "x" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("ページが見つかりません")
    end
  end

  describe "JSON request" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "returns JSON with status and error message" do
      get edit_admin_event_path(999_999), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("application/json")
      expect(response.parsed_body).to eq({ "status" => 404, "error" => "Not Found" })
    end
  end

  describe "HEAD request" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "returns 404 with empty body" do
      head edit_admin_event_path(999_999)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_empty
    end
  end

  describe "static error pages are unchanged" do
    let(:user) { create(:user, role: :general) }

    before do
      post "/signin", params: { email: user.email, password: user.password }
    end

    it "returns 400 page unchanged" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(ActionController::BadRequest)

      get "/events"

      expect(response).to have_http_status(:bad_request)
      expect(response.content_type).to include("text/html")
      expect(response.body).to eq(File.read(Rails.public_path.join("400.html")))
    end

    it "returns 422 page unchanged" do
      allow_any_instance_of(EventsController).to receive(:index).and_raise(ActionController::InvalidAuthenticityToken)

      get "/events"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.content_type).to include("text/html")
      expect(response.body).to eq(File.read(Rails.public_path.join("422.html")))
    end
  end

  describe "fallback when ErrorsController fails to render" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "returns 500 with static fallback page" do
      allow_any_instance_of(ErrorsController).to receive(:not_found).and_raise(RuntimeError, "render failed")

      get edit_admin_event_path(999_999)

      expect(response).to have_http_status(:internal_server_error)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("エラーが発生しました")
      # Rails の failsafe 文言を含まない
      expect(response.body).not_to include("If you are the administrator of this website")
    end
  end
end
