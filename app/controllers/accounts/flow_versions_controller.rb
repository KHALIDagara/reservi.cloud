module Accounts
  class FlowVersionsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    def index
      @flows = current_account.flows.includes(:current_version).order(:name)
    end

    def publish
      flow_version = current_account.flows.find(params[:flow_id])
        .versions.find(params[:id])

      Flows::Publish.call(flow_version:, actor_membership: current_membership)
      redirect_to account_flow_versions_path(current_account), notice: "Flow version published."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_flow_versions_path(current_account), alert: e.message
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only administrators can manage flows."
      end
    end
  end
end