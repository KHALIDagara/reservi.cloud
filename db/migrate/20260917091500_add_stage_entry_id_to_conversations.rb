class AddStageEntryIdToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :stage_entry_id, :string
    add_index :conversations, :stage_entry_id, unique: true,
      where: "stage_entry_id IS NOT NULL",
      name: "index_conversations_on_stage_entry_id"
  end
end
