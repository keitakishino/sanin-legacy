module AuditRecordable
  extend ActiveSupport::Concern

  private

  def record_audit(action, target: nil, result: :success, details: {})
    AuditLog.record!(
      user: current_user,
      action: action,
      target: target,
      result: result,
      details: details || {},
      request_id: request.request_id
    )
  rescue StandardError => e
    Rails.logger.error("[AuditLog] record failed: #{e.class}: #{e.message}")
    nil
  end

  def audit_failure_details(record)
    { reason: record.errors.full_messages.join(", ") }
  end
end
