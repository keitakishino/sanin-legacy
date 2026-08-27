class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :provider, null: false
      t.string :uid, null: false

      t.datetime :created_at, null: false
    end

    add_index :identities, [:provider, :uid], unique: true
    add_index :identities, :user_id
  end
end
