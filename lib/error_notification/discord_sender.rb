require "net/http"
require "securerandom"
require "json"

module ErrorNotification
  class DiscordSender
    TIMEOUT = 3
    QUEUE_LIMIT = 50
    SEND_INTERVAL = 0.5
    MAX_RETRY_WAIT = 5

    class << self
      attr_reader :queue, :worker, :dropped_count, :busy

      def initialize_state
        @mutex ||= Mutex.new
        @queue ||= Thread::SizedQueue.new(QUEUE_LIMIT)
        @worker ||= nil
        @dropped_count ||= 0
        @busy ||= false
      end

      def deliver_later(webhook_url, content:, backtrace_text:)
        initialize_state
        begin
          @queue.push({ webhook_url:, content:, backtrace_text: }, true)
          ensure_worker
          true
        rescue ThreadError
          @mutex.synchronize { @dropped_count += 1 }
          Rails.logger.warn("[ErrorNotification] queue full, dropped")
          false
        end
      end

      def deliver_now(webhook_url, content:, backtrace_text:)
        res = post(URI.parse(webhook_url), content, backtrace_text)

        if res.is_a?(Net::HTTPSuccess)
          return true
        end

        if res.code == "429"
          wait = retry_after_seconds(res)
          if wait.nil? || wait > MAX_RETRY_WAIT
            Rails.logger.warn("[ErrorNotification] Discord rate limited, retry_after=#{wait.inspect} exceeds limit, dropped")
            return false
          end

          pause(wait)
          res = post(URI.parse(webhook_url), content, backtrace_text)

          if res.is_a?(Net::HTTPSuccess)
            return true
          else
            Rails.logger.warn("[ErrorNotification] Discord responded #{res.code} on retry, dropped")
            return false
          end
        end

        Rails.logger.warn("[ErrorNotification] Discord responded #{res.code}")
        false
      rescue StandardError => e
        Rails.logger.warn("[ErrorNotification] delivery failed: #{e.class}")
        false
      end

      def wait_until_idle(timeout: 5)
        end_time = Time.current + timeout
        loop do
          initialize_state
          busy = @mutex.synchronize { @busy }
          if @queue.empty? && !busy
            return true
          end
          break if Time.current > end_time
          sleep 0.01
        end
        false
      end

      def reset!
        initialize_state
        @worker&.kill
        @worker&.join(1)
        @worker = nil
        @queue.clear if @queue.respond_to?(:clear)
        @dropped_count = 0
        @busy = false
      end

      def worker_thread
        initialize_state
        @worker
      end

      def dropped_count
        initialize_state
        @dropped_count
      end

      private

      def ensure_worker
        @mutex.synchronize do
          if @worker&.alive?
            return
          end
          @worker = Thread.new { work_loop }
        end
      end

      def work_loop
        loop do
          job = @queue.pop

          begin
            @mutex.synchronize do
              @busy = true
            end

            dropped = @mutex.synchronize do
              dropped_count = @dropped_count
              @dropped_count = 0
              dropped_count
            end

            content = job[:content]
            if dropped > 0
              content += "\n直前に #{dropped} 件を送信できませんでした"
            end

            if !deliver_now(job[:webhook_url], content:, backtrace_text: job[:backtrace_text])
              @mutex.synchronize do
                @dropped_count += dropped
              end
            end
          rescue StandardError => e
            Rails.logger.warn("[ErrorNotification] work_loop failed: #{e.class}")
          ensure
            @mutex.synchronize do
              @busy = false
            end
            pause(SEND_INTERVAL)
          end
        end
      end

      def post(uri, content, backtrace_text)
        boundary = SecureRandom.hex(16)
        body = build_multipart_body(boundary, content, backtrace_text)

        req = Net::HTTP::Post.new(uri.path)
        req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        req.body = body

        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT,
          write_timeout: TIMEOUT
        ) do |http|
          http.request(req)
        end
      end

      def retry_after_seconds(res)
        header = res["Retry-After"]
        if header
          retry_after = Float(header, exception: false)
          return retry_after if retry_after && retry_after >= 0
        end

        begin
          body = JSON.parse(res.body.to_s)
          retry_after = Float(body["retry_after"], exception: false)
          return retry_after if retry_after && retry_after >= 0
        rescue JSON::ParserError, TypeError
        end

        nil
      end

      def pause(seconds)
        sleep(seconds)
      end

      def build_multipart_body(boundary, content, backtrace_text)
        body = ""

        body += "--#{boundary}\r\n"
        body += "Content-Disposition: form-data; name=\"payload_json\"\r\n"
        body += "Content-Type: application/json\r\n"
        body += "\r\n"
        payload = {
          content:,
          allowed_mentions: { parse: [] },
          attachments: [ { id: 0, filename: "backtrace.txt" } ]
        }
        body += payload.to_json
        body += "\r\n"

        body += "--#{boundary}\r\n"
        body += "Content-Disposition: form-data; name=\"files[0]\"; filename=\"backtrace.txt\"\r\n"
        body += "Content-Type: text/plain; charset=utf-8\r\n"
        body += "\r\n"
        body += backtrace_text
        body += "\r\n"

        body += "--#{boundary}--\r\n"

        body
      end
    end
  end
end
