class MakeProxyOrderItemFoilFrameNullable < ActiveRecord::Migration[8.1]
  def up
    change_column_null :proxy_order_items, :foil, true
    change_column_null :proxy_order_items, :frame, true
  end

  def down
    change_column_null :proxy_order_items, :foil, false, 1
    change_column_null :proxy_order_items, :frame, false, 0
  end
end
