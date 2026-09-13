class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: { to_table: :customers }
      # Composite FK to stages through flow_version_id + current_stage_id
      # uses account-scoped composite indices defined above.
      t.bigint :flow_version_id, null: false
      t.bigint :current_stage_id, null: false
      t.string :process_status, null: false, default: "active"
      t.bigint :owner_id
      t.bigint :team_id
      t.boolean :attention, null: false, default: false
      t.datetime :first_attention_at
      t.datetime :last_activity_at
      t.jsonb :custom_values, null: false, default: {}
      t.timestamps
    end

    add_index :conversations, [:account_id, :id], unique: true
    add_index :conversations, [:account_id, :owner_id]
    add_index :conversations, [:account_id, :team_id]
    add_index :conversations, [:account_id, :attention]
    add_index :conversations, [:account_id, :process_status]
    add_index :conversations, [:flow_version_id, :current_stage_id]

    # Stage reference uses composite FK ensuring current_stage belongs to the
    # pinned flow_version: (flow_version_id, current_stage_id) references
    # stages(flow_version_id, id).
    add_foreign_key :conversations, :stages,
      column: [:flow_version_id, :current_stage_id],
      primary_key: [:flow_version_id, :id]

    # Team FK uses composite (account_id, team_id) for tenant isolation.
    add_foreign_key :conversations, :teams,
      column: [:account_id, :team_id],
      primary_key: [:account_id, :id]

    # Owner FK to agents uses composite (account_id, owner_id).
    # Null owner means unowned; references agents(account_id, id).
    add_foreign_key :conversations, :agents,
      column: [:account_id, :owner_id],
      primary_key: [:account_id, :id]
  end
end