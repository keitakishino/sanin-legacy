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

    # Wrap deliver_later to wait for Thread
    allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_wrap_original do |m, *a, **k|
      m.call(*a, **k).tap(&:join)
    end

    Rails.configuration.x.discord_error_webhook_url = "https://discord.com/api/webhooks/123/abc"
    Rails.configuration.x.release = "abc1234"
  end

  after do
    Rails.configuration.x.discord_error_webhook_url = @original_webhook_url
    Rails.configuration.x.release = @original_release
  end

  describe "C2: Duplicate suppression" do
    def raise_same
      raise ArgumentError, "dup"
    rescue => e
      e
    end

    it "suppresses duplicate errors within 5 minute window" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: false, source: "application.action_dispatch")
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 1.minute do
        error2 = raise_same
        subscriber.report(error2, handled: false, source: "application.action_dispatch")
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 5.minutes + 1.second do
        error3 = raise_same
        subscriber.report(error3, handled: false, source: "application.action_dispatch")
      end

      expect(@sent.size).to eq(2)
      expect(@sent.last.body).to include("同じエラーが 1 件発生しました（5分間まとめ）")
    end

    it "sends different errors within 5 minutes" do
      t0 = Time.current

      travel_to t0 do
        error1 = raise_same
        subscriber.report(error1, handled: false, source: "application.action_dispatch")
      end

      expect(@sent.size).to eq(1)

      travel_to t0 + 1.minute do
        # Different error class
        begin
          raise RuntimeError, "different"
        rescue => e
          subscriber.report(e, handled: false, source: "application.action_dispatch")
        end
      end

      expect(@sent.size).to eq(2)
    end
  end

  describe "handled and source filtering" do
    it "does not send when handled: true and source is not DEFAULT_SOURCE" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      begin
        raise StandardError, "test"
      rescue => e
        subscriber.report(e, handled: true, source: "redis_cache_store.active_support")
      end

      expect(@sent.size).to eq(0)
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
