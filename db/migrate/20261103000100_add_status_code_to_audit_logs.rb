class AddStatusCodeToAuditLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_logs, :status_code, :integer, comment: "HTTP レスポンスのステータスコード（記録前の既存行は null）"
  end
end
