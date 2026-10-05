ActiveSupport.on_load(:action_controller) do
  if Rails.application.config.x.json_request_log
    ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
      begin
        Rails.logger.info(RequestLogFormatter.from_event(event))
      rescue StandardError => e
        Rails.logger.error("Error logging request: #{e.message}")
      end
    end

    ActionController::LogSubscriber.detach_from :action_controller

    Rails::Rack::Logger.prepend(Module.new do
      private

      def started_request_message(_request)
        nil
      end
    end)
  end
end

ActiveSupport.on_load(:action_view) do
  if Rails.application.config.x.json_request_log
    ActionView::LogSubscriber.detach_from :action_view
  end
end
