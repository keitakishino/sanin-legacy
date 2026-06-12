class CreateTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.string :name
      t.string :contact
      t.string :contact_account
      t.string :residue
      t.text :memo
      t.timestamps
    end
  end
end
