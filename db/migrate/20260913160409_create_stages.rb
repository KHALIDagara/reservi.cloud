class CreateStages < ActiveRecord::Migration[8.1]
  def change
    create_table :stages do |t|
      t.references :flow_version, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.integer :position, null: false
      t.jsonb :blocks, null: false, default: []
      t.jsonb :rules, null: false, default: []
      t.jsonb :completion, null: false, default: {}
      t.timestamps
    end

    add_index :stages, [:flow_version_id, :key], unique: true
    add_index :stages, [:flow_version_id, :position], unique: true
    add_index :stages, [:flow_version_id, :id], unique: true
  end
end