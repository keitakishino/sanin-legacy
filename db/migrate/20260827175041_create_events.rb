class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false, comment: "イベント名"
      t.text :description, comment: "イベント説明"
      t.date :event_date, null: false, comment: "イベント開催日"
      t.bigint :created_by_id, comment: "作成者（管理者）のuser_id。FK制約はIssue #28マージ後に別マイグレーションで追加"
      t.string :spreadsheet_id, comment: "Google SheetsファイルID（初回エクスポート時に生成）"
      t.datetime :discarded_at, comment: "論理削除フラグ（null=有効、datetime=削除日時）"
      t.timestamps
    end

    add_index :events, :created_by_id, name: "index_events_on_created_by_id"
    add_index :events, :discarded_at, name: "index_events_on_discarded_at"
    add_index :events, [ :event_date, :discarded_at ], name: "index_events_on_event_date_and_discarded_at"
    add_index :events, :title, name: "index_events_on_title"
  end
end
