class CreateSolidCacheAndQueueTables < ActiveRecord::Migration[8.1]
  def up
    # SolidCache
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
    end
    add_index :solid_cache_entries, :byte_size, name: "index_solid_cache_entries_on_byte_size", if_not_exists: true
    add_index :solid_cache_entries, [:key_hash, :byte_size], name: "index_solid_cache_entries_on_key_hash_and_byte_size", if_not_exists: true
    add_index :solid_cache_entries, :key_hash, unique: true, name: "index_solid_cache_entries_on_key_hash", if_not_exists: true

    # SolidQueue
    create_table :solid_queue_jobs, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :solid_queue_jobs, :active_job_id, name: "index_solid_queue_jobs_on_active_job_id", if_not_exists: true
    add_index :solid_queue_jobs, [:queue_name, :finished_at], name: "index_solid_queue_jobs_on_queue_name_and_finished_at", if_not_exists: true
    add_index :solid_queue_jobs, [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_on_scheduled_at_and_finished_at", if_not_exists: true
    add_index :solid_queue_jobs, :concurrency_key, where: "finished_at IS NULL", name: "index_solid_queue_jobs_on_concurrency_key_when_unfinished", if_not_exists: true

    create_table :solid_queue_scheduled_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_scheduled_executions, [:scheduled_at, :priority], name: "index_solid_queue_dispatch_all", if_not_exists: true
    add_index :solid_queue_scheduled_executions, :job_id, unique: true, name: "index_solid_queue_scheduled_executions_on_job_id", if_not_exists: true

    create_table :solid_queue_ready_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_ready_executions, [:priority, :job_id], name: "index_solid_queue_poll_all", if_not_exists: true
    add_index :solid_queue_ready_executions, [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue", if_not_exists: true
    add_index :solid_queue_ready_executions, :job_id, unique: true, name: "index_solid_queue_ready_executions_on_job_id", if_not_exists: true

    create_table :solid_queue_claimed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_claimed_executions, :job_id, unique: true, name: "index_solid_queue_claimed_executions_on_job_id", if_not_exists: true
    add_index :solid_queue_claimed_executions, [:process_id, :job_id], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id", if_not_exists: true

    create_table :solid_queue_blocked_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_blocked_executions, [:expires_at, :concurrency_key], name: "index_solid_queue_blocked_executions_for_maintenance", if_not_exists: true
    add_index :solid_queue_blocked_executions, [:concurrency_key, :priority, :job_id], name: "index_solid_queue_blocked_executions_for_release", if_not_exists: true
    add_index :solid_queue_blocked_executions, :job_id, unique: true, name: "index_solid_queue_blocked_executions_on_job_id", if_not_exists: true

    create_table :solid_queue_failed_executions, if_not_exists: true do |t|
      t.bigint :job_id, null: false
      t.text :error
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_failed_executions, :job_id, unique: true, name: "index_solid_queue_failed_executions_on_job_id", if_not_exists: true

    create_table :solid_queue_pauses, if_not_exists: true do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_pauses, :queue_name, unique: true, name: "index_solid_queue_pauses_on_queue_name", if_not_exists: true

    create_table :solid_queue_processes, if_not_exists: true do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
    end
    add_index :solid_queue_processes, :last_heartbeat_at, name: "index_solid_queue_processes_on_last_heartbeat_at", if_not_exists: true
    add_index :solid_queue_processes, :supervisor_id, name: "index_solid_queue_processes_on_supervisor_id", if_not_exists: true

    create_table :solid_queue_semaphores, if_not_exists: true do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :solid_queue_semaphores, :key, unique: true, name: "index_solid_queue_semaphores_on_key", if_not_exists: true
    add_index :solid_queue_semaphores, :expires_at, name: "index_solid_queue_semaphores_on_expires_at", if_not_exists: true
  end

  def down
    drop_table :solid_cache_entries, if_exists: true
    drop_table :solid_queue_scheduled_executions, if_exists: true
    drop_table :solid_queue_ready_executions, if_exists: true
    drop_table :solid_queue_claimed_executions, if_exists: true
    drop_table :solid_queue_blocked_executions, if_exists: true
    drop_table :solid_queue_failed_executions, if_exists: true
    drop_table :solid_queue_jobs, if_exists: true
    drop_table :solid_queue_pauses, if_exists: true
    drop_table :solid_queue_processes, if_exists: true
    drop_table :solid_queue_semaphores, if_exists: true
  end
end