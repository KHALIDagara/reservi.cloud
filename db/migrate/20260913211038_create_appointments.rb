class CreateAppointments < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :appointments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string :role_key, null: false
      t.references :scheduled_agent, foreign_key: { to_table: :agents }
      t.string :status, null: false, default: "pending"
      t.datetime :starts_at, precision: 6, null: false
      t.datetime :ends_at, precision: 6, null: false
      t.integer :duration_minutes
      t.string :timezone, null: false, default: "UTC"
      t.text :purpose
      t.string :cancellation_reason
      t.datetime :cancelled_at, precision: 6
      t.datetime :completed_at, precision: 6
      t.bigint :superseded_by_id
      t.timestamps
    end

    # Unique index for current (non-superseded) appointments per conversation+role
    add_index :appointments, [:conversation_id, :role_key],
      unique: true,
      where: "superseded_by_id IS NULL",
      name: "idx_current_appointment_per_role"

    add_index :appointments, [:account_id, :scheduled_agent_id],
      name: "idx_appointments_account_scheduled_agent"

    # Exclusion constraint prevents overlapping confirmed appointments
    # for the same account+agent combination with overlapping time ranges.
    # Only applies when scheduled_agent_id IS NOT NULL and status is 'confirmed'.
    execute <<~SQL
      ALTER TABLE appointments
      ADD CONSTRAINT no_overlapping_confirmed_appointments
      EXCLUDE USING gist (
        account_id WITH =,
        scheduled_agent_id WITH =,
        tsrange(starts_at, ends_at, '[)') WITH &&
      )
      WHERE (scheduled_agent_id IS NOT NULL AND status = 'confirmed');
    SQL
  end

  def down
    drop_table :appointments
  end
end