module ErrorNotification
  class Subscriber
    DEFAULT_SOURCE = "application"

    def initialize
      @throttle = Throttle.new
    end

    def report(error, handled:, severity: nil, context: nil, source: nil)
      webhook_url = Rails.configuration.x.discord_error_webhook_url
      return if webhook_url.blank?

      # Only report unhandled errors or errors from the default source (Rails standard handling)
      return if handled && source != DEFAULT_SOURCE

      fingerprint = "#{error.class.name}|#{error.backtrace&.first || error.message}"
      notify, suppressed = @throttle.check(fingerprint)
      return unless notify

      begin
        controller = context&.dig(:controller)
        request = controller&.is_a?(ActionController::Base) ? controller.request : nil

        # Build notification content
        action_name = if controller.is_a?(ActionController::Base)
          "#{controller.class.name}##{controller.action_name}"
        else
          "-"
        end

        url = if request
          request.base_url + request.filtered_path
        else
          "-"
        end

        timestamp = Time.current.in_time_zone("Asia/Tokyo").strftime("%Y-%m-%d %H:%M:%S JST")

        user_id = if request
          request.session[:user_id]&.to_s || "-"
        else
          "-"
        end

        request_id = request&.request_id || "-"
        release = Rails.configuration.x.release
        params_json = if request
          request.filtered_parameters.except("controller", "action").to_json
        else
          "-"
        end

        # Truncate parameters to 500 chars
        params_json = params_json[0..499] if params_json.size > 500

        content = ":rotating_light: **#{error.class.name}**: #{error.message[0..499]}\n"
        content += "発生箇所: #{action_name}\n"
        content += "URL: #{url}\n"
        content += "発生時刻: #{timestamp}\n"
        content += "user_id: #{user_id}\n"
        content += "request_id: #{request_id}\n"
        content += "リリース: #{release}\n"
        content += "source: #{source}\n"
        content += "パラメータ: #{params_json}"

        if suppressed && suppressed > 0
          content += "\n前回の通知以降、同じエラーが #{suppressed} 件発生しました（5分間まとめ）"
        end

        # Truncate entire content to 1900 chars
        content = content[0..1899] if content.size > 1900

        backtrace_text = "#{error.class.name}: #{error.message}\n"
        backtrace_text += Array(error.backtrace).join("\n")

        cause = error.cause
        while cause
          backtrace_text += "\n\nCaused by #{cause.class}: #{cause.message}\n"
          backtrace_text += Array(cause.backtrace).join("\n")
          cause = cause.cause
        end

        DiscordSender.deliver_later(webhook_url, content:, backtrace_text:)
      rescue StandardError => e
        Rails.logger.warn("[ErrorNotification] subscriber failed: #{e.class}")
      end
    end
  end
end
