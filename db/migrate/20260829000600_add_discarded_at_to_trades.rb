class AddDiscardedAtToTrades < ActiveRecord::Migration[8.1]
  def change
    add_column :trades, :discarded_at, :datetime, comment: "論理削除フラグ（null=有効、datetime=削除日時）"
    add_index :trades, :discarded_at
  end
end
