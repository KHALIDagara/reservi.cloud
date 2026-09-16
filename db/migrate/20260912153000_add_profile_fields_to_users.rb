class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :verified_at, :datetime
    add_column :users, :verification_token_digest, :string
  end
end
