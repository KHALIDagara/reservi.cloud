class AddFlowForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # FlowVersion → Flow FK (deferred from CreateFlowVersions to avoid circular dep)
    add_foreign_key :flow_versions, :flows, column: :flow_id
    add_index :flow_versions, :flow_id

    # Flow → FlowVersion FK (pinned published version)
    add_foreign_key :flows, :flow_versions, column: :current_version_id, if_not_exists: true
    add_index :flows, :current_version_id, where: "current_version_id IS NOT NULL"
  end
end