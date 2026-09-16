class CreateConversationReads < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_reads do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.bigint :last_read_message_id
      t.timestamps
    end

    add_index :conversation_reads, [ :conversation_id, :agent_id ], unique: true
  end
end
