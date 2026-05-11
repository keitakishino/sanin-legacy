class CreateTradeCards < ActiveRecord::Migration[8.1]
  def change
    create_table :wishlists do |t|
      t.belongs_to :trade
      t.string :name
      t.string :language
      t.boolean :foil
      t.string :edition
      t.string :expansion
      t.string :state
      t.timestamps
    end
  end
end
