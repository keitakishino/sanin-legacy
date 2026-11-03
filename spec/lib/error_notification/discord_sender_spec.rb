require "rails_helper"

RSpec.describe ErrorNotification::DiscordSender do
  let(:url) { "https://discord.com/api/webhooks/123/abc" }
  let(:content) { "test content" }
  let(:backtrace_text) { "test backtrace" }

  before do
    @sent = []
  end

  describe "C3: single worker thread" do
    it "creates only one worker thread even with many deliveries" do
      gate = Queue.new

      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        @sent << req
        gate.pop
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      end

      allow(ErrorNotification::DiscordSender).to receive(:pause)

      before_count = Thread.list.size
      20.times do |i|
        ErrorNotification::DiscordSender.deliver_later(url, content: "msg#{i}", backtrace_text:)
      end

      new_thread_count = Thread.list.size - before_count
      expect(new_thread_count).to be <= 1

      worker = ErrorNotification::DiscordSender.worker_thread
      expect(worker).to be_alive
      same_worker = ErrorNotification::DiscordSender.worker_thread
      expect(same_worker).to be(worker)

      wait_for_queue_taken = Time.current + 2
      loop do
        break if @sent.size >= 1
        break if Time.current > wait_for_queue_taken
        sleep 0.01
      end

      expect(@sent.size).to eq(1)

      21.times { gate << true }
      expect(ErrorNotification::DiscordSender.wait_until_idle).to be(true)
      expect(@sent.size).to eq(20)
    end

    it "restarts worker after kill" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) { |req| Net::HTTPNoContent.new("1.1", "204", "No Content") }
      allow(ErrorNotification::DiscordSender).to receive(:pause)

      ErrorNotification::DiscordSender.deliver_later(url, content:, backtrace_text:)
      ErrorNotification::DiscordSender.wait_until_idle

      worker = ErrorNotification::DiscordSender.worker_thread
      expect(worker).to be_alive

      worker.kill
      worker.join(1)

      ErrorNotification::DiscordSender.deliver_later(url, content:, backtrace_text:)
      new_worker = ErrorNotification::DiscordSender.worker_thread
      expect(new_worker).to be_alive
      expect(new_worker).not_to be(worker)

      ErrorNotification::DiscordSender.wait_until_idle
    end
  end

  describe "C4: queue limit and dropped notification appending" do
    it "drops notifications when queue is full and appends count to next delivery" do
      gate = Queue.new

      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        @sent << req
        gate.pop
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      end

      allow(ErrorNotification::DiscordSender).to receive(:pause)

      ErrorNotification::DiscordSender.deliver_later(url, content: "msg0", backtrace_text:)

      wait_for_first_taken = Time.current + 2
      loop do
        break if @sent.size >= 1
        break if Time.current > wait_for_first_taken
        sleep 0.01
      end

      expect(@sent.size).to eq(1)

      (1..50).each do |i|
        result = ErrorNotification::DiscordSender.deliver_later(url, content: "msg#{i}", backtrace_text:)
        expect(result).to be(true)
      end

      3.times do
        result = ErrorNotification::DiscordSender.deliver_later(url, content: "drop", backtrace_text:)
        expect(result).to be(false)
      end

      expect(ErrorNotification::DiscordSender.dropped_count).to eq(3)

      (1..51).each { gate << true }
      expect(ErrorNotification::DiscordSender.wait_until_idle).to be(true)

      expect(@sent.size).to eq(51)
      appended_body = @sent[1].body
      expect(appended_body).to include("直前に 3 件を送信できませんでした")

      expect(ErrorNotification::DiscordSender.dropped_count).to eq(0)
    end

    it "returns quickly even when queue is full" do
      gate = Queue.new

      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) do |req|
        @sent << req
        gate.pop
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      end

      allow(ErrorNotification::DiscordSender).to receive(:pause)

      ErrorNotification::DiscordSender.deliver_later(url, content: "msg0", backtrace_text:)

      wait_for_first_taken = Time.current + 2
      loop do
        break if @sent.size >= 1
        break if Time.current > wait_for_first_taken
        sleep 0.01
      end

      (1..50).each do |i|
        ErrorNotification::DiscordSender.deliver_later(url, content: "msg#{i}", backtrace_text:)
      end

      start_time = Time.current
      ErrorNotification::DiscordSender.deliver_later(url, content: "over", backtrace_text:)
      end_time = Time.current

      expect(end_time - start_time).to be < 0.1
    end
  end

  describe "C5: 429 retry with Retry-After" do
    it "retries on 429 with Retry-After header" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      responses = [
        (res429 = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")),
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      ]
      res429["Retry-After"] = "1"

      allow(http).to receive(:request) { responses.shift }

      pause_calls = []
      allow(ErrorNotification::DiscordSender).to receive(:pause) do |seconds|
        pause_calls << seconds
      end

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(true)
      expect(pause_calls).to include(1.0)
    end

    it "retries on 429 with JSON retry_after" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res429 = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      allow(res429).to receive(:body).and_return('{"retry_after": 1.5}')
      responses = [
        res429,
        Net::HTTPNoContent.new("1.1", "204", "No Content")
      ]

      allow(http).to receive(:request) { responses.shift }

      pause_calls = []
      allow(ErrorNotification::DiscordSender).to receive(:pause) do |seconds|
        pause_calls << seconds
      end

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(true)
      expect(pause_calls).to include(1.5)
    end

    it "drops on 429 with Retry-After exceeding limit" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res429 = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      res429["Retry-After"] = "10"
      allow(http).to receive(:request) { res429 }

      allow(Rails.logger).to receive(:warn)

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(false)
      expect(Rails.logger).to have_received(:warn).with(match(/exceeds limit/))
    end

    it "drops after retry on 429" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res429 = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      res429["Retry-After"] = "0.1"
      res429_2 = Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")
      responses = [ res429, res429_2 ]

      allow(http).to receive(:request) { responses.shift }

      allow(Rails.logger).to receive(:warn)
      allow(ErrorNotification::DiscordSender).to receive(:pause)

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(false)
      expect(Rails.logger).to have_received(:warn).with(match(/responded.*on retry/))
    end
  end

  describe "C7: non-429 errors don't retry" do
    it "does not retry on 500 error" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res500 = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      allow(http).to receive(:request) { res500 }

      allow(Rails.logger).to receive(:warn)

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(false)
    end

    it "does not retry on 400 error" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res400 = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(http).to receive(:request) { res400 }

      allow(Rails.logger).to receive(:warn)

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)

      expect(result).to be(false)
    end

    it "continues to send after failure" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res_fail = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      res_ok = Net::HTTPNoContent.new("1.1", "204", "No Content")
      responses = [ res_fail, res_ok ]

      allow(http).to receive(:request) do
        @sent << 1
        responses.shift
      end

      allow(Rails.logger).to receive(:warn)
      allow(ErrorNotification::DiscordSender).to receive(:pause)

      ErrorNotification::DiscordSender.deliver_later(url, content: "fail", backtrace_text:)
      ErrorNotification::DiscordSender.deliver_later(url, content: "ok", backtrace_text:)

      expect(ErrorNotification::DiscordSender.wait_until_idle).to be(true)
      expect(@sent.size).to eq(2)
    end
  end

  describe "C8: send interval" do
    it "calls pause with SEND_INTERVAL" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) { Net::HTTPNoContent.new("1.1", "204", "No Content") }

      pause_calls = []
      allow(ErrorNotification::DiscordSender).to receive(:pause) do |seconds|
        pause_calls << seconds
      end

      ErrorNotification::DiscordSender.deliver_later(url, content: "msg1", backtrace_text:)
      ErrorNotification::DiscordSender.deliver_later(url, content: "msg2", backtrace_text:)

      ErrorNotification::DiscordSender.wait_until_idle

      expect(pause_calls).to include(0.5)
    end
  end

  describe "deliver_now return value" do
    it "returns true on success" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) { Net::HTTPNoContent.new("1.1", "204", "No Content") }

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)
      expect(result).to be(true)
    end

    it "returns false on failure" do
      http = double("Net::HTTP")
      allow(Net::HTTP).to receive(:start).and_yield(http)

      res_fail = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
      allow(http).to receive(:request) { res_fail }

      allow(Rails.logger).to receive(:warn)

      result = ErrorNotification::DiscordSender.deliver_now(url, content:, backtrace_text:)
      expect(result).to be(false)
    end
  end
end
