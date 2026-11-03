require "rails_helper"

RSpec.describe "Discord notification scope (Issue #418)", type: :request do
  around do |example|
    # テスト環境で DebugExceptions がデバッグ画面を出さないようにする
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    example.run

    Rails.application.env_config["action_dispatch.show_exceptions"] = :rescuable
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = true
  end

  describe "C8: 404/422 do not trigger Discord notifications" do
    let(:admin) { create(:user, role: :admin) }

    before do
      post "/signin", params: { email: admin.email, password: admin.password }
    end

    it "404 error does not send Discord notification" do
      allow_any_instance_of(ErrorNotification::DiscordSender).to receive(:deliver_later)

      # 404 が Discord 通知を送らないことを確認
      expect(ErrorNotification::DiscordSender).not_to receive(:deliver_later)

      get edit_admin_event_path(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "422 error (InvalidAuthenticityToken) does not send Discord notification" do
      allow_any_instance_of(ErrorNotification::DiscordSender).to receive(:deliver_later)
      allow_any_instance_of(SessionsController).to receive(:new).and_raise(ActionController::InvalidAuthenticityToken)

      # 422 が Discord 通知を送らないことを確認
      expect(ErrorNotification::DiscordSender).not_to receive(:deliver_later)

      get "/signin"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
