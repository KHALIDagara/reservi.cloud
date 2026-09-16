module Memberships
  # Authorized role change. Demoting an administrator honors the same
  # last-admin protection as removal.
  module ChangeRole
    module_function

    def call(membership:, role:, actor_membership:)
      account = membership.account

      account.with_lock do
        actor = account.memberships.active.find_by(id: actor_membership.id)
        raise Reservi::Errors::AuthorizationError, "Only an Account administrator can change roles." unless actor&.admin?

        if membership.role == "admin" && role != "admin"
          remaining_admin = account.memberships.active.admins.where.not(id: membership.id).exists?
          raise Reservi::Errors::OperationError, "At least one active administrator must remain." unless remaining_admin
        end

        membership.update!(role:)
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
