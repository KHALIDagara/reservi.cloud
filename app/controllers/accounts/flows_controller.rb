module Accounts
  class FlowsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!

    def index
      @flows = current_account.flows.includes(versions: :stages)
        .order(:name)
    end

    def new
      @flow = current_account.flows.new
    end

    def create
      @flow = current_account.flows.new(flow_params)

      if @flow.save
        # Create an initial draft version with one stage
        version = @flow.versions.create!(version_number: 1, status: "draft")
        version.stages.create!(
          key: "stage_1",
          label: "Stage 1",
          position: 1,
          blocks: [],
          rules: [],
          completion: { "literal" => false }
        )
        redirect_to edit_flow_flow_version_path(current_account, @flow, version),
          notice: "Flow created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @flow = current_account.flows.find(params[:id])
      @versions = @flow.versions.order(version_number: :desc)
      @draft = @flow.versions.draft.order(version_number: :desc).first
    end

    def update
      @flow = current_account.flows.find(params[:id])
      if @flow.update(flow_params)
        redirect_to flows_path(current_account), notice: "Flow updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only administrators can manage flows."
      end
    end

    def flow_params
      params.require(:flow).permit(:name)
    end
  end
end
