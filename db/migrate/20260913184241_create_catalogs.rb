class CreateCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.jsonb :item_attributes, null: false, default: {}
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :catalogs, [ :account_id, :id ], unique: true
    add_index :catalogs, [ :account_id, :title ], unique: true
  end
end
