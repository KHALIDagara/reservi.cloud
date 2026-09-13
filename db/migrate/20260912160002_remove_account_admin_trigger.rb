class RemoveAccountAdminTrigger < ActiveRecord::Migration[8.1]
  # The application-level check in Memberships::Remove is sufficient and works correctly.
  # The trigger was causing false positives due to transaction visibility issues.
  def up
    execute "DROP TRIGGER IF EXISTS reservi_ensure_active_admin ON memberships;"
    execute "DROP FUNCTION IF EXISTS reservi_ensure_active_admin();"
  end

  def down
    # No re-creation - the trigger was problematic
  end
end