class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :locale, null: false, default: "en"
      t.string :timezone, null: false, default: "UTC"
      t.jsonb :settings, null: false, default: {}
      t.boolean :active, null: false, default: true
      # Stable idempotent-create identity, set by Accounts::Create. NULL for accounts
      # created through other future paths; unique when present.
      t.string :creation_operation_key

      t.timestamps
    end

    add_index :accounts, :creation_operation_key, unique: true
  end
end