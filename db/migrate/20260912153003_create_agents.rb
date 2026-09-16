class CreateAgents < ActiveRecord::Migration[8.1]
  def up
    create_table :agents do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false, default: "human"
      t.bigint :membership_id
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :capabilities, null: false, default: {}

      t.timestamps
    end

    add_index :agents, [ :account_id, :membership_id ], unique: true, where: "membership_id IS NOT NULL", name: "index_agents_on_account_and_membership_unique"
    add_index :agents, [ :account_id, :id ], unique: true, name: "index_agents_on_account_id_and_id"
    add_index :agents, :membership_id

    # A human Agent must reference a Membership; an AI Agent must not.
    add_check_constraint :agents, "kind IN ('human', 'ai')", name: "agents_kind_check"
    add_check_constraint :agents,
      "(kind = 'human' AND membership_id IS NOT NULL) OR (kind = 'ai' AND membership_id IS NULL)",
      name: "agents_kind_membership_check"

    add_foreign_key :agents, :memberships, column: [ :account_id, :membership_id ], primary_key: [ :account_id, :id ], name: "fk_agents_membership_account_scoped"
  end

  def down
    drop_table :agents
  end
end
