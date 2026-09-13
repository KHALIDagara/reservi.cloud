class CreateAccountInvitations < ActiveRecord::Migration[8.1]
  def up
    create_table :account_invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false, default: "operator"
      t.bigint :team_ids, array: true, null: false, default: []
      t.bigint :inviter_membership_id, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.string :status, null: false, default: "pending"
      t.string :delivery_status, null: false, default: "pending"
      t.integer :delivery_attempts, null: false, default: 0
      t.string :delivery_token
      t.bigint :accepted_by_membership_id
      t.datetime :accepted_at

      t.timestamps
    end

    # At most one live (pending) invite per Account and normalized email.
    add_index :account_invitations, [:account_id, :email], unique: true, where: "status = 'pending'", name: "index_account_invitations_one_pending_per_account_email"
    add_index :account_invitations, :email
    add_index :account_invitations, [:status, :delivery_status], name: "index_account_invitations_delivery"
    add_index :account_invitations, [:account_id, :id], unique: true, name: "index_account_invitations_on_account_id_and_id"

    add_check_constraint :account_invitations, "role IN ('admin', 'manager', 'operator')", name: "account_invitations_role_check"
    add_check_constraint :account_invitations, "status IN ('pending', 'accepted', 'revoked')", name: "account_invitations_status_check"
    add_check_constraint :account_invitations, "delivery_status IN ('pending', 'delivered', 'failed', 'unknown')", name: "account_invitations_delivery_status_check"

    add_foreign_key :account_invitations, :memberships, column: [:account_id, :inviter_membership_id], primary_key: [:account_id, :id], name: "fk_account_invitations_inviter_account_scoped"
    add_foreign_key :account_invitations, :memberships, column: [:account_id, :accepted_by_membership_id], primary_key: [:account_id, :id], name: "fk_account_invitations_accepted_by_account_scoped"
  end

  def down
    drop_table :account_invitations
  end
end