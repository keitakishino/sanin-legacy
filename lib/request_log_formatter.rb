class RequestLogFormatter
  def self.format(time:, request_id:, user_id:, method:, path:, controller:, action:, status:, duration_ms:, params:)
    filtered_params = filter_params(params)
    data = {
      time: format_time(time),
      request_id: request_id,
      user_id: user_id,
      method: method,
      path: path,
      controller: controller,
      action: action,
      status: status,
      duration_ms: duration_ms&.round(1),
      params: filtered_params
    }
    JSON.generate(data)
  end

  def self.from_event(event)
    payload = event.payload
    request = payload[:request]
    request_id = request&.request_id
    user_id = payload[:user_id]
    method = payload[:method]
    path = payload[:path]
    controller = payload[:controller]
    action = payload[:action]
    status = payload[:status] || (payload[:exception_object] ? ActionDispatch::ExceptionWrapper.status_code_for_exception(payload[:exception_object].class.name) : nil)
    duration_ms = event.duration
    params = payload[:params]

    format(
      time: Time.current,
      request_id: request_id,
      user_id: user_id,
      method: method,
      path: path,
      controller: controller,
      action: action,
      status: status,
      duration_ms: duration_ms,
      params: params
    )
  end

  private

  def self.format_time(time)
    time.in_time_zone("Asia/Tokyo").iso8601(3)
  end

  def self.filter_params(params)
    return {} if params.nil?

    params_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(params_hash)
    filtered.except("controller", "action")
  end
end
