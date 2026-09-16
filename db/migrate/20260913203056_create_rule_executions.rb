class CreateRuleExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :rule_executions do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :stage, null: false, foreign_key: true
      t.string :rule_key, null: false
      t.string :execution_key, null: false
      t.boolean :predicate_result, null: false
      t.string :status, null: false, default: "evaluated"
      t.jsonb :actions_executed, null: false, default: []
      t.text :error_message
      t.text :explanation
      t.timestamps
    end

    add_index :rule_executions, :execution_key, unique: true
    add_index :rule_executions, [ :conversation_id, :stage_id, :rule_key ],
      name: "idx_rule_execs_on_conversation_stage_rule"
  end
end
