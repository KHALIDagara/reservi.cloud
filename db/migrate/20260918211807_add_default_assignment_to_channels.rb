class AddDefaultAssignmentToChannels < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:channels, :default_agent_id)
      add_reference :channels, :default_agent, foreign_key: { to_table: :agents }
    end

    unless column_exists?(:channels, :default_team_id)
      add_reference :channels, :default_team, foreign_key: { to_table: :teams }
    end

    # A channel may specify at most one default (agent or team), not both
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          DO $$
          BEGIN
            IF NOT EXISTS (
              SELECT 1 FROM pg_constraint WHERE conname = 'channels_default_assignment_check'
            ) THEN
              ALTER TABLE channels
              ADD CONSTRAINT channels_default_assignment_check
              CHECK (default_agent_id IS NULL OR default_team_id IS NULL);
            END IF;
          END
          $$;
        SQL
      end
      dir.down do
        execute <<-SQL.squish
          ALTER TABLE channels
          DROP CONSTRAINT IF EXISTS channels_default_assignment_check
        SQL
      end
    end

    # Fix: ensure operation_key column exists on appointments.
    # The migration 20260917234502 adds it with null:true but some DB states
    # are missing it due to structure.sql drift.
    unless column_exists?(:appointments, :operation_key)
      add_column :appointments, :operation_key, :string, null: true
      add_index :appointments, %i[conversation_id role_key operation_key],
        unique: true,
        where: "operation_key IS NOT NULL AND superseded_by_id IS NULL",
        name: "idx_appointments_operation_key_uniq"
    end
  end
end