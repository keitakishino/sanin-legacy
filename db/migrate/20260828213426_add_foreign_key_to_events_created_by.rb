class AddForeignKeyToEventsCreatedBy < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :events, :users, column: :created_by_id
  end
end
