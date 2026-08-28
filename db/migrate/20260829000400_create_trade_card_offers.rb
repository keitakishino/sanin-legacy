class CreateTradeCardOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_card_offers do |t|
      t.references :trade, null: false, foreign_key: true
      t.string :card_name, null: false
      t.integer :quantity, null: false
      t.integer :language, null: false
      t.integer :condition, null: false
      t.integer :foil, null: false
      t.integer :frame, null: false
      t.boolean :pw_mark, null: false, default: false
      t.references :expansion, foreign_key: true, null: true
      t.integer :amount, null: true
      t.text :note, null: true

      t.timestamps
    end

    add_check_constraint :trade_card_offers, "quantity > 0", name: "trade_card_offers_quantity_positive"
  end
end
