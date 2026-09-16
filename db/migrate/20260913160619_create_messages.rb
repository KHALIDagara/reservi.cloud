class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :agent, foreign_key: true
      t.string :author_name, null: false, default: ""
      t.text :content, null: false, default: ""
      t.string :direction, null: false, default: "inbound"
      t.string :delivery_status, null: false, default: "local"
      t.string :operation_key
      t.timestamps
    end

    add_index :messages, [ :conversation_id, :id ], unique: true
    add_index :messages, [ :conversation_id, :created_at ]
    add_index :messages, [ :conversation_id, :direction ]
  end
end
