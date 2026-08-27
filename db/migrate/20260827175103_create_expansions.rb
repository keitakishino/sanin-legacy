class CreateExpansions < ActiveRecord::Migration[8.1]
  def change
    create_table :expansions do |t|
      t.string :scryfall_set_code, null: false
      t.string :name, null: false
      t.string :name_ja
      t.timestamps
    end

    add_index :expansions, :scryfall_set_code, unique: true
  end
end
