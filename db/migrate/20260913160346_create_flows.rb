class CreateFlows < ActiveRecord::Migration[8.1]
  def change
    create_table :flows do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.bigint :current_version_id
      t.timestamps
    end

    add_index :flows, [ :account_id, :id ], unique: true
    add_index :flows, [ :account_id, :name ], unique: true
  end
end
