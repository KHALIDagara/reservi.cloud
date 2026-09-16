module Invitations
  # Rotates the token so the old link dies, resets the delivery state and
  # re-enqueues a fresh delivery. Requires the invitation to still be pending.
  module Resend
    module_function

    def call(invitation:, actor_membership:)
      policy = Accounts::Policy.new(actor_membership)
      raise Reservi::Errors::AuthorizationError, "Only an Account administrator can resend invitations." unless policy.admin?

      unless invitation.pending?
        raise Reservi::Errors::OperationError, "Only pending invitations can be resent."
      end

      invitation.transaction do
        invitation.rotate_token!
        invitation.delivery_status = "pending"
        invitation.delivery_attempts = 0
        invitation.save!
      end
      Invitations::DeliverJob.perform_later(invitation)
      invitation
    end
  end
end
