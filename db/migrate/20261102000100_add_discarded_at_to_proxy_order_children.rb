class AddDiscardedAtToProxyOrderChildren < ActiveRecord::Migration[8.0]
  def change
    add_column :proxy_order_price_lines, :discarded_at, :datetime
    add_index :proxy_order_price_lines, :discarded_at

    add_column :proxy_order_participants, :discarded_at, :datetime
    add_index :proxy_order_participants, :discarded_at

    add_column :proxy_order_allocations, :discarded_at, :datetime
    add_index :proxy_order_allocations, :discarded_at
  end
end
