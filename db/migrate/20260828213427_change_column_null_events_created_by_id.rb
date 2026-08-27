class ChangeColumnNullEventsCreatedById < ActiveRecord::Migration[8.1]
  def change
    change_column_null :events, :created_by_id, false
  end
end
