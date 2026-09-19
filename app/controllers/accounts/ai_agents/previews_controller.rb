module Accounts
  module AiAgents
    class PreviewsController < ApplicationController
      before_action :require_account_access!
      before_action :require_admin!
      before_action :set_ai_agent

      def new
      end

      def create
        # Use a temporary conversation with a sample customer for preview
        # Never mutate the real conversation state.
        account = current_account
        customer = account.customers.first || account.customers.create!(name: "Preview Customer")
        flow_version = account.flows.where.not(current_version_id: nil).first&.current_version
        return redirect_to account_ai_agent_path(account, @ai_agent), alert: "No published Flow configured." unless flow_version

        first_stage = flow_version.stages.order(:position).first
        preview_conv = account.conversations.new(
          customer: customer,
          flow_version: flow_version,
          current_stage: first_stage,
          process_status: "active",
          custom_values: {}
        )

        result = AiRuns::Preview.call(
          agent: @ai_agent,
          conversation: preview_conv,
          user_message: params[:user_message].to_s
        )

        @response_text   = result[:content] || result[:response] || "(no response)"
        @tool_calls      = result[:tool_calls] || []
        @workspace       = result[:workspace] || {}
      rescue => e
        redirect_to account_ai_agent_path(current_account, @ai_agent),
          alert: "Preview failed: #{e.message}"
      end

      private

      def require_admin!
        unless Accounts::Policy.new(current_membership).admin?
          raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage AI agents."
        end
      end

      def set_ai_agent
        @ai_agent = current_account.agents.ai.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to account_ai_agents_path(current_account), alert: "AI agent not found."
      end
    end
  end
end