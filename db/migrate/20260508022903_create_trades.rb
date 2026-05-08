class CreateTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.string :name
      t.integer :contact
      t.string :contact_account
      t.integer :residue
      t.text :memo
      t.timestamps
    end
  end
end
