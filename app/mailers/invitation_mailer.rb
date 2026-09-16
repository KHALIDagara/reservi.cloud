class InvitationMailer < ApplicationMailer
  def invitation(invitation, raw_token)
    @invitation = invitation
    @account = invitation.account
    @accept_url = accept_invitation_url(token: raw_token)
    @expires_at = invitation.expires_at

    mail(to: invitation.email, subject: "You're invited to #{@account.name} on Reservi")
  end
end
