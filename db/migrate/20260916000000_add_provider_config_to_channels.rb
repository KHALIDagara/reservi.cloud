class AddProviderConfigToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :provider_config, :jsonb, null: false, default: {}

    create_table :webhook_receipts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.string :provider_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, default: {}
      t.timestamp :processed_at
      t.timestamps
    end

    add_index :webhook_receipts, [:channel_id, :provider_event_id], unique: true,
      name: "idx_webhook_receipts_on_channel_and_event"
    add_index :webhook_receipts, [:account_id, :created_at],
      name: "idx_webhook_receipts_on_account_created_at"
  end
end