module Memberships
  # Deactivation ("removal") plus the human Agent of the same Membership.
  # Preserves history; the row stays with active=false (INV-061/INV-131).
  # Serializes on the Account row lock before the last-admin check; the
  # reservi_ensure_active_admin trigger remains the database backstop for
  # concurrent/direct write paths.
  module Remove
    module_function

    def call(membership:, actor_membership:)
      account = membership.account

      account.with_lock do
        actor = account.memberships.find_by(id: actor_membership.id)
        self_removal = membership.id == actor_membership.id

        # Authorization: only admins can remove members (including self-removal)
        unless actor&.active? && actor.admin?
          raise Reservi::Errors::AuthorizationError, "Only an Account administrator can remove members."
        end
        if membership.role == "admin" && membership.active?
          remaining_admin = account.memberships.active.admins.where.not(id: membership.id).exists?
          raise Reservi::Errors::OperationError, "At least one active administrator must remain." unless remaining_admin
        end

        membership.update!(active: false)
        membership.agent&.update!(active: false)
        membership
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.cause&.message&.include?("reservi_ensure_active_admin")
        raise Reservi::Errors::OperationError, "At least one active administrator must remain."
      end

      raise
    end
  end
end