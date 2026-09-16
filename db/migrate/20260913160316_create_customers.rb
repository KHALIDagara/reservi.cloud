class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.string :phone
      t.string :email_address
      t.string :locale, default: "en"
      t.jsonb :custom_values, null: false, default: {}
      t.integer :profile_revision, null: false, default: 1
      t.timestamps
    end

    add_index :customers, [ :account_id, :id ], unique: true
    add_index :customers, [ :account_id, :email_address ], unique: true, where: "email_address IS NOT NULL"
  end
end
