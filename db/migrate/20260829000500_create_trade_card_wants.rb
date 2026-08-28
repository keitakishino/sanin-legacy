class CreateTradeCardWants < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_card_wants do |t|
      t.references :trade, null: false, foreign_key: true
      t.string :card_name, null: false
      t.integer :quantity, null: false
      t.integer :language, null: true
      t.integer :conditions, array: true, null: true
      t.integer :foil, null: true
      t.integer :frame, null: true
      t.references :expansion, foreign_key: true, null: true
      t.integer :amount, null: true
      t.text :note, null: true

      t.timestamps
    end

    add_check_constraint :trade_card_wants, "quantity > 0", name: "trade_card_wants_quantity_positive"
  end
end
