module Accounts
  class AiAgentsController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!, except: %i[index show]
    before_action :set_ai_agent, only: %i[show edit update]

    def index
      @ai_agents = current_account.agents.ai.order(:name)
    end

    def show
      @configuration = @ai_agent.agent_configuration
    end

    def new
      @ai_agent = current_account.agents.new(kind: "ai")
    end

    def create
      agent = current_account.agents.create!(
        kind: "ai",
        name: agent_params[:name],
        operational_status: "draft",
        active: true
      )

      config = agent.agent_configurations.create!(
        account: current_account,
        role: agent_params[:instructions]&.truncate(200),
        guidance_config: { instructions: agent_params[:instructions].to_s },
        capability_config: capability_config,
        version_number: 1,
        status: "draft"
      )
      agent.update!(agent_configuration_id: config.id)

      redirect_to account_ai_agent_path(current_account, agent),
        notice: "AI agent created. Configure and activate it to make it assignable."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      @ai_agent = current_account.agents.new(kind: "ai")
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def edit
      @configuration = @ai_agent.agent_configuration || @ai_agent.build_agent_configuration(account: current_account)
    end

    def update
      @configuration = @ai_agent.agent_configuration || @ai_agent.build_agent_configuration(account: current_account)

      @ai_agent.update!(name: agent_params[:name])

      @configuration.update!(
        role: agent_params[:instructions]&.truncate(200),
        guidance_config: { instructions: agent_params[:instructions].to_s }
      )

      redirect_to account_ai_agent_path(current_account, @ai_agent),
        notice: "AI agent updated."
    rescue ActiveRecord::RecordInvalid => e
      render :edit, status: :unprocessable_entity
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

    def agent_params
      params.require(:agent).permit(:name, :instructions)
    end

    def capability_config
      # V1: all active AI agents get all capabilities by default
      {
        reply: true,
        update_fields: true,
        select_items: true,
        create_appointments: true,
        search_knowledge: true,
        add_notes: true,
        handoff: true,
        cancel_appointments: false
      }
    end
  end
end