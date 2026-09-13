class CreateItemSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :item_selections do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :catalog, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.string :role_key, null: false
      t.integer :ordinal
      t.jsonb :snapshot, null: false, default: {}
      t.timestamps
    end

    add_index :item_selections, [:conversation_id, :role_key, :item_id], unique: true, name: "idx_item_selections_on_conversation_role_item"
    add_index :item_selections, [:conversation_id, :role_key], name: "idx_item_selections_on_conversation_role"
    add_index :item_selections, [:account_id, :id], unique: true

    add_foreign_key :item_selections, :conversations,
      column: [:account_id, :conversation_id],
      primary_key: [:account_id, :id],
      name: "fk_item_selections_conversation_account_scoped"
  end
end