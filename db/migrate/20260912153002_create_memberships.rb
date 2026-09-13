class CreateMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "operator"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :memberships, [:account_id, :user_id], unique: true
    # Composite tenant key so children can FK (account_id, parent_id) safely.
    add_index :memberships, [:account_id, :id], unique: true
    add_check_constraint :memberships, "role IN ('admin', 'manager', 'operator')", name: "memberships_role_check"
  end

  def down
    drop_table :memberships
  end
end