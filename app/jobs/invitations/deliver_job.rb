class Invitations::DeliverJob < ApplicationJob
  queue_as :mailers

  # Bounded, idempotent delivery of a pending invitation. The raw token lives
  # only in the encrypted delivery payload and is erased after successful
  # delivery; a lost wakeup is repaired by Invitations::Resend.
  MAX_ATTEMPTS = 3

  def perform(invitation)
    invitation = AccountInvitation.find_by(id: invitation) if invitation.is_a?(Integer)
    return unless invitation
    return unless invitation.status == "pending"
    return if invitation.delivery_token.blank?

    invitation.increment!(:delivery_attempts)
    InvitationMailer.invitation(invitation, invitation.delivery_token).deliver_now
    invitation.update!(delivery_status: "delivered", delivery_token: nil)
  rescue StandardError
    if invitation && invitation.delivery_attempts < MAX_ATTEMPTS
      self.class.set(wait: 15.seconds * invitation.delivery_attempts).perform_later(invitation)
    else
      invitation&.update!(delivery_status: "failed")
    end
  end
end