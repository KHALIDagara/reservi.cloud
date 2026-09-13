class CreateTeamMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :team_memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :team_id, null: false
      t.bigint :agent_id, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :team_memberships, [:team_id, :agent_id], unique: true, name: "index_team_memberships_on_team_and_agent"
    add_index :team_memberships, :agent_id

    add_foreign_key :team_memberships, :teams, column: [:account_id, :team_id], primary_key: [:account_id, :id], name: "fk_team_memberships_team_account_scoped"
    add_foreign_key :team_memberships, :agents, column: [:account_id, :agent_id], primary_key: [:account_id, :id], name: "fk_team_memberships_agent_account_scoped"
  end

  def down
    drop_table :team_memberships
  end
end