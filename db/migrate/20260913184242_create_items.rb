class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :catalog, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2
      t.string :currency, null: false, default: "USD"
      t.string :unit
      t.jsonb :attributes_json, null: false, default: {}
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :items, [:account_id, :catalog_id, :title], unique: true
    add_index :items, [:account_id, :id], unique: true
    add_index :items, [:catalog_id, :id], unique: true
  end
end