class CreateMessageDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :message_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :operation_key, null: false
      t.string :provider_message_id
      t.text :error_message
      t.integer :retry_count, null: false, default: 0
      t.datetime :last_attempt_at, precision: 6
      t.timestamps
    end

    add_index :message_deliveries, :operation_key, unique: true
    add_index :message_deliveries, [ :channel_id, :status ],
      name: "idx_deliveries_on_channel_status"
    add_index :message_deliveries, [ :account_id, :message_id ], unique: true,
      name: "idx_deliveries_on_account_message"
  end
end
