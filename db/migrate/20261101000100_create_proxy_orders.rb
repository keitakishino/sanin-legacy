class CreateProxyOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :proxy_orders do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0, comment: "0=ordered 1=arrived 2=completed"
      t.decimal :tax_usd, precision: 10, scale: 2, null: false, default: 0
      t.decimal :customs_usd, precision: 10, scale: 2, null: false, default: 0
      t.decimal :shipping_usd, precision: 10, scale: 2, null: false, default: 0
      t.decimal :usd_jpy_rate, precision: 10, scale: 4
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    create_table :proxy_order_items do |t|
      t.references :proxy_order, null: false, foreign_key: true
      t.string :card_name, null: false
      t.references :expansion, foreign_key: true
      t.integer :foil, null: false
      t.integer :frame, null: false
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    create_table :proxy_order_price_lines do |t|
      t.references :proxy_order_item, null: false, foreign_key: true
      t.decimal :unit_price_usd, precision: 10, scale: 2, null: false
      t.integer :quantity, null: false
      t.integer :lost_quantity, null: false, default: 0

      t.timestamps
    end
    add_check_constraint :proxy_order_price_lines, "quantity > 0", name: "proxy_order_price_lines_quantity_positive"
    add_check_constraint :proxy_order_price_lines, "lost_quantity >= 0 AND lost_quantity <= quantity", name: "proxy_order_price_lines_lost_quantity_range"
    add_check_constraint :proxy_order_price_lines, "unit_price_usd >= 0", name: "proxy_order_price_lines_unit_price_non_negative"

    create_table :proxy_order_participants do |t|
      t.references :proxy_order, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :guest_name
      t.datetime :handed_over_at

      t.timestamps
    end
    add_index :proxy_order_participants, [ :proxy_order_id, :user_id ], unique: true, where: "user_id IS NOT NULL"
    add_check_constraint :proxy_order_participants, "(user_id IS NULL) <> (guest_name IS NULL)", name: "proxy_order_participants_user_or_guest"

    create_table :proxy_order_allocations do |t|
      t.references :proxy_order_item, null: false, foreign_key: true
      t.references :proxy_order_participant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :lost_quantity, null: false, default: 0

      t.timestamps
    end
    add_index :proxy_order_allocations, [ :proxy_order_item_id, :proxy_order_participant_id ], unique: true, name: "index_proxy_order_allocations_on_item_and_participant"
    add_check_constraint :proxy_order_allocations, "quantity > 0", name: "proxy_order_allocations_quantity_positive"
    add_check_constraint :proxy_order_allocations, "lost_quantity >= 0 AND lost_quantity <= quantity", name: "proxy_order_allocations_lost_quantity_range"
  end
end
