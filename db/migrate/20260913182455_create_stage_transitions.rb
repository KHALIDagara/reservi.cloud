class CreateStageTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :stage_transitions do |t|
      t.references :conversation, null: false, foreign_key: true
      t.bigint :from_stage_id, null: false
      t.bigint :to_stage_id, null: true
      t.string :entry_identity, null: false
      t.string :reason
      t.jsonb :input_revisions, null: false, default: {}
      t.timestamps
    end

    add_index :stage_transitions, [ :conversation_id, :entry_identity ], unique: true
    add_index :stage_transitions, [ :conversation_id, :id ], unique: true
    add_foreign_key :stage_transitions, :stages, column: :from_stage_id
    add_foreign_key :stage_transitions, :stages, column: :to_stage_id
  end
end
