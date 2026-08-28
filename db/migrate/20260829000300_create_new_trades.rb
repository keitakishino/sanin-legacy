class CreateNewTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :offers_total_amount, null: false, default: 0
      t.integer :wants_total_amount, null: false, default: 0
      t.integer :net_amount, null: false, default: 0
      t.references :completed_by, foreign_key: { to_table: :users }, null: true
      t.datetime :completed_at, null: true
      t.text :cancelled_reason, null: true
      t.datetime :spreadsheet_exported_at, null: true
      t.string :spreadsheet_tab_name, null: true
      t.references :spreadsheet_exported_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :trades, [:event_id, :user_id], unique: true
  end
end
