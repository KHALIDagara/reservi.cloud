module Accounts
  class InvitationsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    PAGE_SIZE = 50

    def index
      @invitations = current_account.account_invitations.order(id: :desc).limit(PAGE_SIZE)
      redirect_to account_people_path(current_account)
    end

    def new
      @invitation = current_account.account_invitations.new(role: "operator")
      @teams = current_account.teams.active.order(:name)
    end

    def create
      Invitations::Create.call(
        account: current_account,
        actor_membership: current_membership,
        emails: invitation_params[:emails],
        role: invitation_params[:role],
        team_ids: invitation_params[:team_ids]
      )
      redirect_to account_people_path(current_account), notice: "Invitation sent."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to new_account_invitation_path(current_account), alert: e.message
    end

    def resend
      invitation = current_account.account_invitations.find(params[:id])
      Invitations::Resend.call(invitation:, actor_membership: current_membership)
      redirect_to account_people_path(current_account), notice: "Invitation resent."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_people_path(current_account), alert: e.message
    end

    def revoke
      invitation = current_account.account_invitations.find(params[:id])
      Invitations::Revoke.call(invitation:, actor_membership: current_membership)
      redirect_to account_people_path(current_account), notice: "Invitation revoked."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_people_path(current_account), alert: e.message
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage invitations."
      end
    end

    def invitation_params
      params.require(:invitation).permit(:emails, :role, team_ids: [])
    end
  end
end