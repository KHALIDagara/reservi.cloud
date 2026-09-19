class AddAttachmentsToMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :attachments do |t|
      t.references :message, null: false, foreign_key: true
      t.string :kind, null: false
      t.timestamps
    end

    add_index :attachments, %i[message_id kind]
  end
end