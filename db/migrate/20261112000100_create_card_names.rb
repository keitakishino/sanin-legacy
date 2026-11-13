class CreateCardNames < ActiveRecord::Migration[7.1]
  def change
    create_table :card_names do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :card_names, :name, unique: true
    add_index :card_names, "lower(name) text_pattern_ops", name: "index_card_names_on_lower_name_pattern"
  end
end
