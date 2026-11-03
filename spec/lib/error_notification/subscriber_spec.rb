require "rails_helper"

RSpec.describe ErrorNotification::Subscriber do
  let(:subscriber) { described_class.new }

  before do
    @sent = []
    @original_webhook_url = Rails.configuration.x.discord_error_webhook_url
    @original_release = Rails.configuration.x.release

    # Mock HTTP
    http = double("Net::HTTP")
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |req|
      @sent << req
      Net::HTTPNoContent.new("1.1", "204", "No Content")
    end

    allow(ErrorNotification::DiscordSender).to receive(:pause)

    Rails.configuration.x.discord_error_webhook_url = "https://discord.com/api/webhooks/123/abc"
    Rails.configuration.x.release = "abc1234"
  end

  def flush
    expect(ErrorNotification::DiscordSender.wait_until_idle).to be(true)
  end

  after do
    Rails.configuration.x.discord_error_webhook_url = @original_webhook_url
    Rails.configuration.x.release = @original_release
  end

  describe "500 (handled: false, source: application.action_dispatch) is not throttled" do
    def raise_same
      raise ArgumentError, "dup"
    rescue => e
      e
    end

    it "sends 500 multiple times without throttle within 5 minute window" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: false, source: "application.action_dispatch")
        flush
      end

      expect(@sent.size).to eq(1)
      expect(@sent.last.body).not_to include("5分間まとめ")

      travel_to t0 + 1.minute do
        error2 = raise_same
        subscriber.report(error2, handled: false, source: "application.action_dispatch")
        flush
      end

      expect(@sent.size).to eq(2)
      expect(@sent.last.body).not_to include("5分間まとめ")

      travel_to t0 + 5.minutes + 1.second do
        error3 = raise_same
        subscriber.report(error3, handled: false, source: "application.action_dispatch")
        flush
      end

      expect(@sent.size).to eq(3)
      expect(@sent.last.body).not_to include("5分間まとめ")
    end

    it "sends 500 every time when reported in quick succession" do
      error = raise_same
      subscriber.report(error, handled: false, source: "application.action_dispatch")
      subscriber.report(error, handled: false, source: "application.action_dispatch")
      subscriber.report(error, handled: false, source: "application.action_dispatch")
      flush

      expect(@sent.size).to eq(3)
      @sent.each do |req|
        expect(req.body).not_to include("5分間まとめ")
      end
    end
  end

  describe "non-500 reports are throttled" do
    def raise_same
      raise ArgumentError, "dup"
    rescue => e
      e
    end

    it "throttles handled: true with source: application" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: true, source: "application")
        flush
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 1.minute do
        error2 = raise_same
        subscriber.report(error2, handled: true, source: "application")
        flush
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 5.minutes + 1.second do
        error3 = raise_same
        subscriber.report(error3, handled: true, source: "application")
        flush
      end

      expect(@sent.size).to eq(2)
      expect(@sent.last.body).to include("同じエラーが 1 件発生しました（5分間まとめ）")
    end

    it "throttles handled: false with other source" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: false, source: "job.active_job")
        flush
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 1.minute do
        error2 = raise_same
        subscriber.report(error2, handled: false, source: "job.active_job")
        flush
      end

      expect(@sent.size).to eq(1)
    end
  end

  describe "different errors within 5 minutes" do
    def raise_same
      raise ArgumentError, "dup"
    rescue => e
      e
    end

    it "sends different errors without throttling" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: false, source: "application.action_dispatch")
        flush
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 1.minute do
        begin
          raise RuntimeError, "different"
        rescue => e
          subscriber.report(e, handled: false, source: "application.action_dispatch")
          flush
        end
      end

      expect(@sent.size).to eq(2)
    end
  end

  describe "handled and source filtering" do
    it "does not send when handled: true and source is not DEFAULT_SOURCE" do
      begin
        raise StandardError, "test"
      rescue => e
        subscriber.report(e, handled: true, source: "redis_cache_store.active_support")
      end

      expect(@sent.size).to eq(0)
    end

    it "does not send when webhook_url is not set" do
      original_webhook_url = Rails.configuration.x.discord_error_webhook_url
      Rails.configuration.x.discord_error_webhook_url = nil

      begin
        raise StandardError, "test"
      rescue => e
        subscriber.report(e, handled: false, source: "application.action_dispatch")
      end

      expect(@sent.size).to eq(0)

      Rails.configuration.x.discord_error_webhook_url = original_webhook_url
    end
  end

  describe "error handling in subscriber" do
    it "does not raise when DiscordSender fails" do
      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_raise(Net::OpenTimeout)

      expect do
        begin
          raise StandardError, "test"
        rescue => e
          subscriber.report(e, handled: false, source: "application.action_dispatch")
        end
      end.not_to raise_error
    end
  end
end
