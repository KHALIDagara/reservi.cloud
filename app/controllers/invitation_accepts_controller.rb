class InvitationAcceptsController < ApplicationController
  before_action :require_authentication
  before_action :set_invitation

  def show
    reason = Invitations::Accept.blocking_reason(invitation: @invitation, user: Current.user, token: @token)
    if reason
      redirect_to accounts_path, alert: reason
      return
    end

    @role = @invitation.role
    @teams = @invitation.account.teams.active.where(id: @invitation.team_ids).order(:name)
  end

  def accept
    Invitations::Accept.call(invitation: @invitation, token: @token, user: Current.user)
    redirect_to account_home_path(@invitation.account), notice: "Welcome to #{@invitation.account.name}."
  rescue Reservi::Errors::OperationError => e
    redirect_to accounts_path, alert: e.message
  end

  private

  def set_invitation
    @token = params[:token]
    @invitation = AccountInvitation.find_by!(token_digest: User.digest(@token))
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path, alert: "This invitation link is invalid."
  end
end