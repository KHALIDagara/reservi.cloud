module Accounts
  module AiAgents
    class ActivationsController < ApplicationController
      before_action :require_account_access!
      before_action :require_admin!
      before_action :set_ai_agent

      def create
        config = @ai_agent.agent_configuration
        unless config
          redirect_to edit_account_ai_agent_path(current_account, @ai_agent),
            alert: "Configure the AI agent before activating it." and return
        end

        config.update!(status: "published", published_at: Time.current)
        @ai_agent.update!(operational_status: "active")

        redirect_to account_ai_agent_path(current_account, @ai_agent),
          notice: "#{@ai_agent.name} is now active and can be assigned to conversations."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to account_ai_agent_path(current_account, @ai_agent),
          alert: "Could not activate: #{e.message}"
      end

      def destroy
        @ai_agent.update!(operational_status: "paused")

        redirect_to account_ai_agent_path(current_account, @ai_agent),
          notice: "#{@ai_agent.name} has been paused."
      rescue ActiveRecord::RecordInvalid => e
        redirect_to account_ai_agent_path(current_account, @ai_agent),
          alert: "Could not pause: #{e.message}"
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