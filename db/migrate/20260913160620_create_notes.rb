class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.text :content, null: false, default: ""
      t.timestamps
    end

    add_index :notes, [:conversation_id, :id], unique: true
  end
end