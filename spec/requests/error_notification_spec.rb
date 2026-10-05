require "rails_helper"

RSpec.describe "Error Notification", type: :request do
  let(:user) { create(:user) }

  shared_context "with mocked HTTP and config" do
    before do
      @sent = []
      @threads = []
      @original_webhook_url = Rails.configuration.x.discord_error_webhook_url
      @original_release = Rails.configuration.x.release
      @subscriber = ErrorNotification::Subscriber.new

      # Register subscriber to Rails.error
      Rails.error.subscribe(@subscriber)

      # Mock HTTP
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        @sent << req
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      end

      # Wrap deliver_later to allow controlling Thread joining
      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_wrap_original do |m, *a, **k|
        thread = m.call(*a, **k)
        @threads << thread
        thread
      end
    end

    after do
      # Restore original config values
      Rails.configuration.x.discord_error_webhook_url = @original_webhook_url
      Rails.configuration.x.release = @original_release

      # Unsubscribe the test subscriber to avoid affecting other tests
      Rails.error.unsubscribe(@subscriber) if defined?(@subscriber)

      # Clear the mock to prevent carry-over to other specs
      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_call_original
    end
  end

  describe "C1: Basic error notification with HTTP send" do
    include_context "with mocked HTTP and config"

    before do
      Rails.configuration.x.discord_error_webhook_url = "https://discord.com/api/webhooks/123/abc"
      Rails.configuration.x.release = "abc1234"
    end

    it "sends error notification with correct content and backtrace attachment" do
      travel_to Time.utc(2026, 10, 5, 1, 21, 0) do
        # Create a mock controller context with request
        mock_request = double("request",
          base_url: "http://www.example.com",
          filtered_path: "/events?q=foo&token=%5BFILTERED%5D",
          request_id: "test-req-123",
          session: { user_id: user.id },
          filtered_parameters: { "q" => "foo", "token" => "[FILTERED]", "controller" => "events", "action" => "index" }
        )

        mock_controller = double("EventsController")
        allow(mock_controller).to receive(:is_a?).with(ActionController::Base).and_return(true)
        allow(mock_controller).to receive_messages(
          class: EventsController,
          action_name: "index",
          request: mock_request
        )

        error = RuntimeError.new("boom")
        error.set_backtrace([ "/app/app/controllers/events_controller.rb:5:in `index'" ])

        @subscriber.report(
          error,
          handled: false,
          severity: :warning,
          context: { controller: mock_controller },
          source: "application.action_dispatch"
        )
      end

      @threads.each(&:join)

      expect(@sent.size).to eq(1)
      req = @sent.first

      # Net::HTTP::Post request body contains multipart form data
      expect(req["Content-Type"]).to start_with("multipart/form-data")
      expect(req.body).to include("RuntimeError")
      expect(req.body).to include("boom")
      expect(req.body).to include("EventsController#index")
      expect(req.body).to include("http://www.example.com/events?")
      expect(req.body).to include("2026-10-05 10:21:00 JST")
      expect(req.body).to include("user_id: #{user.id}")
      expect(req.body).to include("test-req-123")
      expect(req.body).to include("abc1234")
      expect(req.body).to include("\\\"token\\\":\\\"[FILTERED]\\\"")
      expect(req.body).not_to include("secret123")
      expect(req.body).to include("filename=\"backtrace.txt\"")
      expect(req.body).to include("text/plain")
    end
  end

  describe "C3: Delivery failure does not affect response" do
    include_context "with mocked HTTP and config"

    before do
      Rails.configuration.x.discord_error_webhook_url = "https://discord.com/api/webhooks/123/abc"
      Rails.configuration.x.release = "abc1234"

      # Configure Rails to show exceptions
      Rails.application.env_config["action_dispatch.show_exceptions"] = :all
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    end

    after do
      # Restore exception settings
      Rails.application.env_config["action_dispatch.show_exceptions"] = :rescuable
      Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = true
    end

    it "returns 500 response when HTTP fails and delivery is attempted" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

      error = RuntimeError.new("boom")
      @subscriber.report(
        error,
        handled: false,
        severity: :warning,
        context: {},
        source: "application.action_dispatch"
      )

      @threads.each(&:join)

      # Verify that HTTP was attempted even though it failed
      expect(Net::HTTP).to have_received(:start)
    end

    it "returns response before delivery completes" do
      gate = Queue.new
      allow(Net::HTTP).to receive(:start) do
        gate.pop
        raise Net::ReadTimeout
      end

      error = RuntimeError.new("boom")
      @subscriber.report(
        error,
        handled: false,
        severity: :warning,
        context: {},
        source: "application.action_dispatch"
      )

      expect(@threads.first.alive?).to be true

      gate << true
      @threads.each(&:join)
    end
  end

  describe "C4: No HTTP request when webhook_url is not set" do
    before do
      Rails.configuration.x.discord_error_webhook_url = nil
      @original_webhook_url = nil
    end

    after do
      Rails.configuration.x.discord_error_webhook_url = @original_webhook_url
    end

    it "does not make HTTP request when webhook_url is nil" do
      expect(Net::HTTP).not_to receive(:start)

      subscriber = ErrorNotification::Subscriber.new
      error = RuntimeError.new("boom")
      subscriber.report(
        error,
        handled: false,
        severity: :warning,
        context: {},
        source: "application.action_dispatch"
      )
    end
  end
end
