class DropTrades < ActiveRecord::Migration[8.1]
  def change
    drop_table :trades
  end
end
