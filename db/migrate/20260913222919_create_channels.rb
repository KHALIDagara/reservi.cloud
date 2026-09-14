class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :provider_type, null: false
      t.boolean :active, null: false, default: true
      t.string :inbound_token, null: false
      t.string :default_team_name
      t.integer :rate_limit_per_minute, default: 10
      t.timestamps
    end

    add_index :channels, [:account_id, :name], unique: true
    add_index :channels, :inbound_token, unique: true

    create_table :channel_threads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.string :external_thread_id, null: false
      t.string :external_contact_id
      t.string :external_contact_name
      t.timestamps
    end

    add_index :channel_threads, [:channel_id, :external_thread_id], unique: true,
      name: "idx_channel_threads_on_channel_and_thread"
    add_index :channel_threads, [:account_id, :conversation_id],
      name: "idx_channel_threads_on_account_conversation"
  end
end