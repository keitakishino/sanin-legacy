class RemoveSpreadsheetColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :spreadsheet_id, :string, comment: "Google SheetsファイルID（初回エクスポート時に生成）"
    remove_reference :trades, :spreadsheet_exported_by, foreign_key: { to_table: :users }, index: true, null: true
    remove_column :trades, :spreadsheet_exported_at, :datetime, null: true
    remove_column :trades, :spreadsheet_tab_name, :string, null: true
  end
end
