class AddDefaultAssignmentToChannels < ActiveRecord::Migration[8.1]
  def change
    add_reference :channels, :default_agent, foreign_key: { to_table: :agents }
    add_reference :channels, :default_team, foreign_key: { to_table: :teams }

    # A channel may specify at most one default (agent or team), not both
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          ALTER TABLE channels
          ADD CONSTRAINT channels_default_assignment_check
          CHECK (default_agent_id IS NULL OR default_team_id IS NULL)
        SQL
      end
      dir.down do
        execute <<-SQL.squish
          ALTER TABLE channels
          DROP CONSTRAINT IF EXISTS channels_default_assignment_check
        SQL
      end
    end
  end
end