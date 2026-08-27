class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :code, null: false
      t.references :issued_by, foreign_key: { to_table: :users }, null: false
      t.integer :status, default: 0, null: false
      t.datetime :expires_at, null: false
      t.references :used_by, foreign_key: { to_table: :users }, null: true
      t.datetime :used_at
      t.string :signup_token
      t.datetime :signup_token_expires_at

      t.datetime :created_at, null: false
    end

    add_index :invitations, :code, unique: true
    add_index :invitations, :signup_token, unique: true
    add_index :invitations, :expires_at
    add_index :invitations, :status
  end
end
