module Invitations
  # Revokes a pending invitation and erases its delivery payload; the token
  # becomes unusable. Accepted invitations stay accepted (history).
  module Revoke
    module_function

    def call(invitation:, actor_membership:)
      policy = Accounts::Policy.new(actor_membership)
      raise Reservi::Errors::AuthorizationError, "Only an Account administrator can revoke invitations." unless policy.admin?
      raise Reservi::Errors::OperationError, "Only pending invitations can be revoked." unless invitation.pending?

      invitation.update!(status: "revoked", delivery_token: nil)
      invitation
    end
  end
end