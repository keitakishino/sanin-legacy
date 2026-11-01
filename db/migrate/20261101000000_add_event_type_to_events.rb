class AddEventTypeToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :event_type, :integer, null: false, default: 0, comment: "イベント種類（0=trade 1=tournament 2=proxy_order）"
  end
end
