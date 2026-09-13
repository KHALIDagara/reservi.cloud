module Accounts
  class MembershipsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    def update_role
      membership = current_account.memberships.find(params[:id])
      Memberships::ChangeRole.call(
        membership:,
        role: params[:membership][:role],
        actor_membership: current_membership
      )
      redirect_to account_people_path(current_account), notice: "Role updated."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_people_path(current_account), alert: e.message
    end

    def remove
      membership = current_account.memberships.find_by(id: params[:id])
      if membership.nil?
        render status: :not_found, plain: "Not found"
        return
      end
      
      Memberships::Remove.call(membership:, actor_membership: current_membership)
      redirect_to account_people_path(current_account), notice: "Member removed."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_people_path(current_account), alert: e.message
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage members."
      end
    end
  end
end