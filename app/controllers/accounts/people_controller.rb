module Accounts
  class PeopleController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    def index
      @members = current_account.memberships.active.includes(:user, :agent).order(:id)
      @invitations = current_account.account_invitations.pending.order(id: :desc)
      @teams = current_account.teams.active.order(:name)
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage people."
      end
    end
  end
end
