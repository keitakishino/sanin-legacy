class CreateTradeCards < ActiveRecord::Migration[8.1]
  def change
    create_table :wishlists do |t|
      t.belongs_to :trade
      t.string :name
      t.integer :language
      t.boolean :foil
      t.integer :edition
      t.string :expansion
      t.integer :state
      t.timestamps
    end
  end
end
