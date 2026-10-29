class AddUsernameToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :username, :string
  end
end
