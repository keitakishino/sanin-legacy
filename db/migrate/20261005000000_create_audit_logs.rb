class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.bigint :user_id, comment: "操作者の user_id（ユーザー削除後も履歴を残すため FK は張らない）"
      t.string :action, null: false, comment: "操作の種類。例: event.discard"
      t.string :target_type, comment: "対象リソースのクラス名"
      t.bigint :target_id, comment: "対象リソースの ID"
      t.integer :result, null: false, comment: "0=成功, 1=失敗"
      t.jsonb :details, null: false, default: {}, comment: "変更内容・失敗理由"
      t.string :request_id, comment: "リクエスト ID"
      t.datetime :created_at, null: false

      t.index :created_at
      t.index [ :target_type, :target_id ]
    end
  end
end
