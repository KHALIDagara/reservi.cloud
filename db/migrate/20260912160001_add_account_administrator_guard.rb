class AddAccountAdministratorGuard < ActiveRecord::Migration[8.1]
  # INV-131: at least one active Account administrator must remain. Application
  # operations serialize on the Account row lock; this trigger is the database
  # backstop for any write path (including direct SQL) that would remove the
  # last active administrator.
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reservi_ensure_active_admin()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM memberships
          WHERE account_id = OLD.account_id
            AND role = 'admin'
            AND active = true
            AND id <> OLD.id
        ) THEN
          RETURN COALESCE(NEW, OLD);
        END IF;
        RAISE EXCEPTION 'at least one active administrator must remain for account %', OLD.account_id;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER reservi_ensure_active_admin
      BEFORE UPDATE OF active, role OR DELETE ON memberships
      FOR EACH ROW
      WHEN (OLD.role = 'admin' AND OLD.active = true)
      EXECUTE FUNCTION reservi_ensure_active_admin();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS reservi_ensure_active_admin ON memberships;"
    execute "DROP FUNCTION IF EXISTS reservi_ensure_active_admin();"
  end
end
