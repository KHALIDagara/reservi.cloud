class CreateFieldDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :field_definitions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :scope, null: false # "customer" or "conversation"
      t.string :key, null: false
      t.string :label, null: false, default: ""
      t.string :field_type, null: false # text, number, boolean, single_choice, multi_choice, date
      t.jsonb :options, null: false, default: [] # choice options when type is choice
      t.jsonb :constraints, null: false, default: {} # min, max, required, pattern, etc.
      t.string :built_in_binding # name, phone, email_address, locale when mapping to canonical Customer column
      t.integer :position, null: false, default: 0
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :field_definitions, [ :account_id, :scope, :key ], unique: true
    add_index :field_definitions, [ :account_id, :scope, :position ]
    add_index :field_definitions, [ :account_id, :id ], unique: true

    add_check_constraint :field_definitions,
      "scope IN ('customer', 'conversation')",
      name: "field_definitions_scope_check"

    add_check_constraint :field_definitions,
      "field_type IN ('text', 'number', 'boolean', 'single_choice', 'multi_choice', 'date')",
      name: "field_definitions_type_check"
  end
end
