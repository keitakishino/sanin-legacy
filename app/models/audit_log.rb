class AuditLog < ApplicationRecord
  RETENTION_PERIOD = 3.months
  EXCEPTION_MESSAGE_LIMIT = 1_000
  EXCEPTION_MESSAGE_LINE_LIMIT = 300
  BACKTRACE_LINES_LIMIT = 200
  BACKTRACE_CHARS_LIMIT = 30_000
  CAUSE_DEPTH_LIMIT = 5
  TRUNCATION_MARK = "…（省略）"

  belongs_to :user, optional: true

  enum :result, { success: 0, failure: 1 }, prefix: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  def self.record!(user: nil, user_id: nil, action:, target: nil, result:, details: {}, request_id: nil, status_code: nil)
    begin
      purge_expired_if_needed
      transaction(requires_new: true) do
        create!(
          user_id: user&.id || user_id,
          action: action.to_s,
          target_type: target&.class&.name,
          target_id: target&.id,
          result: result,
          details: details || {},
          request_id: request_id,
          status_code: status_code
        )
      end
    rescue StandardError => e
      Rails.logger.error("[AuditLog] record failed: #{e.class}: #{e.message}")
      nil
    end
  end

  def self.purge_expired_if_needed
    return if where(created_at: Time.current.beginning_of_day..).exists?

    begin
      where(created_at: ...RETENTION_PERIOD.ago).delete_all
    rescue StandardError => e
      Rails.logger.error("[AuditLog] purge failed: #{e.class}: #{e.message}")
    end
  end

  def self.apply_status_code(ids, status_code)
    return if ids.blank?

    where(id: ids).update_all(status_code: status_code)
  end

  def self.exception_details(exception, path:, http_method:)
    return {
      "reason" => "unknown error",
      "path" => path,
      "http_method" => http_method
    } if exception.nil?

    error_class = exception.class.name
    message = format_exception_message(exception.message.to_s)
    reason = "#{error_class}: #{message.split("\n").first}"
    backtrace_str = format_backtrace(exception.backtrace || [])
    causes = collect_causes(exception)

    # バックトレースの文字数制限を計算
    total_backtrace_chars = backtrace_str.bytesize
    allocated_chars = BACKTRACE_CHARS_LIMIT - total_backtrace_chars

    causes_data = causes.map do |cause_exc|
      cause_backtrace = format_backtrace(cause_exc.backtrace || [])
      if allocated_chars > 0
        if cause_backtrace.bytesize > allocated_chars
          cause_backtrace = cause_backtrace[0...allocated_chars] + TRUNCATION_MARK
        end
        allocated_chars -= cause_backtrace.bytesize
      else
        cause_backtrace = TRUNCATION_MARK
      end

      {
        "error_class" => cause_exc.class.name,
        "message" => format_exception_message(cause_exc.message.to_s),
        "backtrace" => cause_backtrace
      }
    end

    {
      "reason" => reason,
      "error_class" => error_class,
      "message" => message,
      "backtrace" => backtrace_str,
      "causes" => causes_data,
      "path" => path,
      "http_method" => http_method
    }
  end

  def self.format_exception_message(msg)
    lines = msg.lines.map { |line| line.rstrip[0...EXCEPTION_MESSAGE_LINE_LIMIT] }.join("\n")
    lines.length > EXCEPTION_MESSAGE_LIMIT ? lines[0...EXCEPTION_MESSAGE_LIMIT] + TRUNCATION_MARK : lines
  end

  def self.format_backtrace(backtrace)
    lines = backtrace.first(BACKTRACE_LINES_LIMIT)
    result = lines.join("\n")
    result += "\n#{TRUNCATION_MARK}" if backtrace.length > BACKTRACE_LINES_LIMIT
    result
  end

  def self.collect_causes(exception)
    causes = []
    visited = Set.new
    current = exception

    while current.cause && causes.length < CAUSE_DEPTH_LIMIT
      current = current.cause
      object_id = current.object_id
      break if visited.include?(object_id)

      visited.add(object_id)
      causes << current
    end

    causes
  end

  def to_line
    parts = []
    parts << created_at.strftime("%Y-%m-%d %H:%M")

    if user_id
      role = user&.role || "削除済み"
      parts << "user #{user_id} (#{role})"
    else
      parts << "user -"
    end

    parts << action
    label = result_success? ? "成功" : "失敗"
    label += "(#{status_code})" if status_code
    parts << label

    if target_type
      parts << "#{target_type}##{target_id || '-'}"
    else
      parts << "-"
    end

    parts << "request_id=#{request_id || '-'}"

    line = parts.join("  ")

    if details.present? && details.is_a?(Hash)
      if details.key?("backtrace")
        line += "  理由: #{details['reason'] || details['error_class'] || '-'}"
      elsif details["reason"]
        line += "  理由: #{details['reason']}"
      else
        line += "  details=#{details.to_json}"
      end
    end

    line
  end
end
