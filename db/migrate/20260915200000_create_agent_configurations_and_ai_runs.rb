class CreateAgentConfigurationsAndAiRuns < ActiveRecord::Migration[8.1]
  def up
    # ── Agents: operational_status ──────────────────────────
    add_column :agents, :operational_status, :string, null: false, default: "draft"
    add_check_constraint :agents,
      "operational_status IN ('draft', 'active', 'paused', 'archived')",
      name: "agents_operational_status_check"

    # ── agent_configurations ────────────────────────────────
    create_table :agent_configurations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent,   null: false, foreign_key: true
      t.integer    :version_number,        null: false
      t.string     :status,                null: false, default: "draft"
      t.text       :role
      t.jsonb      :guidance_config,       null: false, default: {}
      t.jsonb      :capability_config,     null: false, default: {}
      t.string     :provider_type
      t.string     :model_identifier
      t.integer    :budget_limit_cents
      t.integer    :max_concurrent_runs,   null: false, default: 1
      t.datetime   :published_at, precision: 6
      t.timestamps
    end

    add_check_constraint :agent_configurations,
      "status IN ('draft', 'published')",
      name: "agent_configurations_status_check"

    add_index :agent_configurations, [ :agent_id, :version_number ],
      unique: true,
      name: "idx_agent_configurations_agent_version"

    add_index :agent_configurations, [ :agent_id, :status ],
      name: "idx_agent_configurations_agent_status"

    # ── Agents: agent_configuration_id FK ───────────────────
    add_column :agents, :agent_configuration_id, :bigint
    add_index :agents, [ :account_id, :agent_configuration_id ],
      name: "idx_agents_on_account_and_agent_config"
    add_foreign_key :agents, :agent_configurations,
      column: :agent_configuration_id

    # ── ai_runs ─────────────────────────────────────────────
    create_table :ai_runs do |t|
      t.references :account,              null: false, foreign_key: true
      t.references :conversation,         null: false, foreign_key: true
      t.references :agent,                null: false, foreign_key: true
      t.references :agent_configuration,  null: false, foreign_key: true
      t.string     :status,               null: false,
                    default: "admitted"
      t.string     :trigger,              null: false
      t.string     :admission_token,      null: false
      t.integer    :budget_reservation_cents
      t.integer    :conversation_revision, null: false, default: 0
      t.jsonb      :usage_json,           null: false, default: {}
      t.datetime   :started_at, precision: 6
      t.datetime   :completed_at, precision: 6
      t.datetime   :failed_at, precision: 6
      t.text       :failure_reason
      t.timestamps
    end

    add_check_constraint :ai_runs,
      "status IN ('admitted', 'evaluating', 'completed', 'failed', 'cancelled')",
      name: "ai_runs_status_check"

    add_index :ai_runs, :admission_token,
      unique: true,
      name: "idx_ai_runs_admission_token"

    add_index :ai_runs, [ :conversation_id, :status ],
      name: "idx_ai_runs_conversation_status"

    add_index :ai_runs, [ :agent_id, :status ],
      name: "idx_ai_runs_agent_status"

    # ── Accounts: generation / admission counters ───────────
    add_column :accounts, :guidance_generation, :integer, null: false, default: 0
    add_column :accounts, :knowledge_generation, :integer, null: false, default: 0
    add_column :accounts, :access_generation,   :integer, null: false, default: 0
    add_column :accounts, :admission_counter,   :integer, null: false, default: 0

    # ── Conversations: revision counter ─────────────────────
    add_column :conversations, :revision, :integer, null: false, default: 0
  end

  def down
    remove_column :conversations, :revision

    remove_column :accounts, :admission_counter
    remove_column :accounts, :access_generation
    remove_column :accounts, :knowledge_generation
    remove_column :accounts, :guidance_generation

    drop_table :ai_runs

    remove_foreign_key :agents, :agent_configurations, column: :agent_configuration_id
    remove_index :agents, name: "idx_agents_on_account_and_agent_config"
    remove_column :agents, :agent_configuration_id

    drop_table :agent_configurations

    remove_check_constraint :agents, name: "agents_operational_status_check"
    remove_column :agents, :operational_status
  end
end
