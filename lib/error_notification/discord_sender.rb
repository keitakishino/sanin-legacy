require "net/http"
require "securerandom"

module ErrorNotification
  class DiscordSender
    TIMEOUT = 3

    def self.deliver_later(webhook_url, content:, backtrace_text:)
      Thread.new { deliver_now(webhook_url, content:, backtrace_text:) }
    end

    def self.deliver_now(webhook_url, content:, backtrace_text:)
      uri = URI.parse(webhook_url)
      boundary = SecureRandom.hex(16)

      body = build_multipart_body(boundary, content, backtrace_text)

      req = Net::HTTP::Post.new(uri.path)
      req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      req.body = body

      begin
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT,
          write_timeout: TIMEOUT
        ) do |http|
          res = http.request(req)
          unless res.is_a?(Net::HTTPSuccess)
            Rails.logger.warn("[ErrorNotification] Discord responded #{res.code}")
          end
        end
      rescue StandardError => e
        Rails.logger.warn("[ErrorNotification] delivery failed: #{e.class}")
      end
    end

    private

    def self.build_multipart_body(boundary, content, backtrace_text)
      body = ""

      # Part 1: payload_json
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

      # Part 2: files[0]
      body += "--#{boundary}\r\n"
      body += "Content-Disposition: form-data; name=\"files[0]\"; filename=\"backtrace.txt\"\r\n"
      body += "Content-Type: text/plain; charset=utf-8\r\n"
      body += "\r\n"
      body += backtrace_text
      body += "\r\n"

      # Final boundary
      body += "--#{boundary}--\r\n"

      body
    end
  end
end
