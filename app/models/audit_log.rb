class AuditLog < ApplicationRecord
  RETENTION_PERIOD = 3.months

  belongs_to :user, optional: true

  enum :result, { success: 0, failure: 1 }, prefix: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  def self.record!(user: nil, action:, target: nil, result:, details: {}, request_id: nil, status_code: nil)
    begin
      purge_expired_if_needed
      transaction(requires_new: true) do
        create!(
          user_id: user&.id,
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
      if details["reason"]
        line += "  理由: #{details['reason']}"
      else
        line += "  details=#{details.to_json}"
      end
    end

    line
  end
end
