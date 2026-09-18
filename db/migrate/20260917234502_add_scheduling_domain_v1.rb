class AddSchedulingDomainV1 < ActiveRecord::Migration[8.1]
  def change
    # ── Agent calendar settings (one-to-one, scoped to Account) ──────────────
    create_table :calendar_settings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent,   null: false, foreign_key: true
      t.string     :timezone, null: false
      t.jsonb      :weekly_hours, null: false, default: {}
      t.timestamps
    end
    add_index :calendar_settings, [ :account_id, :agent_id ], unique: true,
      name: "idx_calendar_settings_account_agent_unique"

    # ── Individual-day exceptions (closed days, special hours) ───────────────
    create_table :calendar_exceptions do |t|
      t.references :calendar_setting, null: false, foreign_key: true
      t.date       :date, null: false
      t.jsonb      :intervals, null: false, default: [] # [] = closed all day
      t.timestamps
    end
    add_index :calendar_exceptions, [ :calendar_setting_id, :date ], unique: true,
      name: "idx_calendar_exceptions_setting_date_unique"

    # ── Appointment domain upgrades ──────────────────────────────────────────
    # 1. Optimistic locking prevents stale operations on the same row.
    # 2. created_by tracks the scheduling actor independent of scheduled_agent.
    # 3. operation_key supports idempotent creation.
    # 4. Ensure superseded confirmed records cannot block new current bookings.

    add_column :appointments, :lock_version, :integer, null: false, default: 0
    add_reference :appointments, :created_by, foreign_key: { to_table: :agents }, null: true
    add_column :appointments, :operation_key, :string, null: true
    add_index :appointments, [ :conversation_id, :role_key, :operation_key ],
      unique: true,
      where: "operation_key IS NOT NULL AND superseded_by_id IS NULL",
      name: "idx_appointments_operation_key_uniq"

    # Exclusion constraints include superseded confirmed records, which can
    # incorrectly block new current bookings. Drop and recreate, filtering
    # superseded rows out of the constraint domain.
    remove_exclusion_constraint :appointments, name: "no_overlapping_confirmed_appointments"

    execute <<~SQL
      ALTER TABLE appointments
      ADD CONSTRAINT no_overlapping_confirmed_appointments
      EXCLUDE USING gist (
        account_id WITH =,
        scheduled_agent_id WITH =,
        tsrange(starts_at, ends_at, '[)'::text) WITH &&
      )
      WHERE (
        scheduled_agent_id IS NOT NULL
        AND status = 'confirmed'
        AND (superseded_by_id IS NULL OR superseded_by_id = 0)
      );
    SQL

    # ── Lightweight appointment event history ────────────────────────────────
    create_table :appointment_events do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :actor, null: true, foreign_key: { to_table: :agents }
      t.string     :action, null: false
      t.jsonb      :before_state, default: {}
      t.jsonb      :after_state,  default: {}
      t.timestamps
    end
    add_index :appointment_events, [ :appointment_id, :created_at ],
      name: "idx_appointment_events_lookup"
  end
end