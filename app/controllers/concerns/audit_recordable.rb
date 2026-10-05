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

  def report_operation_failure(action, record, details: {})
    failure_details = audit_failure_details(record).merge(details)

    begin
      Rails.error.report(
        ErrorNotification::OperationFailed.new("#{action} failed: #{record.class.name}##{record.id}: #{failure_details[:reason]}"),
        handled: true, severity: :error,
        context: { audit_action: action, target_type: record.class.name, target_id: record.id, reason: failure_details[:reason] }
      )
    rescue StandardError => e
      Rails.logger.error("[OperationFailure] report failed: #{e.class}: #{e.message}")
    end

    record_audit(action, target: record, result: :failure, details: failure_details)
  end
end
