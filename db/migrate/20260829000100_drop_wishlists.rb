class DropWishlists < ActiveRecord::Migration[8.1]
  def change
    drop_table :wishlists
  end
end
