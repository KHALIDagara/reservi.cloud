class CreateFlowVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :flow_versions do |t|
      t.bigint :flow_id, null: false
      t.integer :version_number, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.timestamps
    end

    add_index :flow_versions, [ :flow_id, :version_number ], unique: true
    add_index :flow_versions, [ :flow_id, :id ], unique: true
  end
end
