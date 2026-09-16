module Accounts
  class ConversationsController < ApplicationController
    before_action :require_account_access!
    before_action :set_conversation, only: %i[show create_message create_note claim unclaim cancel panel update_field update_customer_field reassign create_appointment confirm_appointment cancel_appointment]
    PAGE_SIZE = 50

    def index
      redirect_to account_inbox_path(current_account)
    end

    def show
      @messages = @conversation.messages.chronological.includes(:agent)
      @notes = @conversation.notes.chronological.includes(:agent)
      touch_read_cursor!
    end

    def new
      @customers = current_account.customers.order(:name).limit(100)
      @conversation = current_account.conversations.new
    end

    def create
      agent = current_membership.agent
      conversation = Conversations::Create.call(
        account: current_account,
        customer_attributes: customer_params,
        agent:,
        content: conversation_params[:initial_message],
        team_id: agent.teams.first&.id
      )
      redirect_to account_conversation_path(current_account, conversation), notice: "Conversation created."
    rescue Reservi::Errors::OperationError => e
      redirect_to new_account_conversation_path(current_account), alert: e.message
    end

    def create_message
      message = Messages::Create.call(
        conversation: @conversation,
        agent: current_membership.agent,
        content: params[:content],
        direction: "outbound"
      )
      redirect_to account_conversation_path(current_account, @conversation)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def create_note
      note = Notes::Create.call(
        conversation: @conversation,
        agent: current_membership.agent,
        content: params[:content]
      )
      redirect_to account_conversation_path(current_account, @conversation)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def claim
      Conversations::Claim.call(conversation: @conversation, agent: current_membership.agent)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Conversation claimed."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_inbox_path(current_account), alert: e.message
    end

    def unclaim
      Conversations::Unclaim.call(conversation: @conversation, agent: current_membership.agent)
      redirect_to account_inbox_path(current_account), notice: "Conversation released."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def cancel
      Conversations::Cancel.call(
        conversation: @conversation,
        agent: current_membership.agent,
        reason: params[:reason]
      )
      redirect_to account_inbox_path(current_account), notice: "Conversation cancelled."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    # ── Magic side panel ────────────────────────────────────────────────

    def panel
      @stage = @conversation.current_stage
      @stage_blocks = @stage&.blocks || []
      load_fields if has_block_type?("field")
      load_catalogs if has_block_type?("catalog")
      load_appointments if has_block_type?("appointment")
      @account_agents = current_account.agents.active.order(:name)
      render partial: "panel", layout: false
    end

    def update_field
      ConversationFields::Update.call(
        conversation: @conversation,
        key: params[:key],
        value: params[:value]
      )
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update_customer_field
      CustomerFields::Update.call(
        customer: @conversation.customer,
        key: params[:key],
        value: params[:value],
        actor_membership: current_membership
      )
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def reassign
      agent = current_account.agents.active.find_by(id: params[:agent_id])
      return render json: { error: "Agent not found" }, status: :not_found unless agent

      if @conversation.owner_id.present?
        Conversations::Unclaim.call(conversation: @conversation, agent: @conversation.owner)
      end
      Conversations::Claim.call(conversation: @conversation, agent: agent)
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def create_appointment
      Appointments::Create.call(
        conversation: @conversation,
        role_key: params[:role_key],
        starts_at: params[:starts_at],
        scheduled_agent: current_membership.agent
      )
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def confirm_appointment
      appointment = current_account.appointments.find_by(
        id: params[:appointment_id],
        conversation_id: @conversation.id
      )
      return render json: { error: "Appointment not found" }, status: :not_found unless appointment

      Appointments::Confirm.call(appointment: appointment)
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def cancel_appointment
      appointment = current_account.appointments.find_by(
        id: params[:appointment_id],
        conversation_id: @conversation.id
      )
      return render json: { error: "Appointment not found" }, status: :not_found unless appointment

      Appointments::Cancel.call(appointment: appointment)
      head :ok
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def set_conversation
      @conversation = current_account.conversations.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to account_inbox_path(current_account), alert: "Conversation not found."
    end

    def touch_read_cursor!
      read = @conversation.conversation_reads.find_or_initialize_by(agent: current_membership.agent)
      last_message = @conversation.messages.order(id: :desc).first
      if last_message && (read.new_record? || read.last_read_message_id.to_i < last_message.id)
        read.update!(last_read_message_id: last_message.id)
      end
    end

    def customer_params
      params.require(:conversation).permit(:name, :email_address, :phone).to_h.symbolize_keys
    end

    def conversation_params
      params.require(:conversation).permit(:initial_message)
    end

    # ── Panel helpers ───────────────────────────────────────────────────

    def has_block_type?(type)
      @stage_blocks.any? { |b| b["type"] == type }
    end

    def load_fields
      field_keys = @stage_blocks.select { |b| b["type"] == "field" }.map { |b| b["key"] }.compact
      return if field_keys.empty?

      @field_definitions = current_account.field_definitions.active
        .where(scope: %w[customer conversation], key: field_keys)
        .index_by(&:key)

      # Split by scope, merge current values
      @customer_fields = {}
      @conversation_fields = {}
      @field_definitions.each do |key, fd|
        if fd.scope == "customer"
          @customer_fields[key] = { definition: fd, value: @conversation.customer.custom_values[key] }
        else
          @conversation_fields[key] = { definition: fd, value: @conversation.custom_values[key] }
        end
      end
    end

    def load_catalogs
      catalog_blocks = @stage_blocks.select { |b| b["type"] == "catalog" && b["catalog_key"].present? }
      return if catalog_blocks.empty?

      catalog_keys = catalog_blocks.map { |b| b["catalog_key"] }.uniq
      @catalogs = current_account.catalogs.active.where(title: catalog_keys).includes(:items)
      @item_selections = @conversation.item_selections.index_by(&:role_key)

      @catalog_roles = {}
      catalog_blocks.each do |b|
        next unless b["role_key"].present? && b["catalog_key"].present?
        @catalog_roles[b["role_key"]] = b["catalog_key"]
      end
    end

    def load_appointments
      appointment_blocks = @stage_blocks.select { |b| b["type"] == "appointment" && b["role_key"].present? }
      return if appointment_blocks.empty?

      role_keys = appointment_blocks.map { |b| b["role_key"] }
      @appointments = @conversation.appointments
        .where(role_key: role_keys)
        .where("superseded_by_id IS NULL OR superseded_by_id = 0")
        .index_by(&:role_key)
    end
  end
end
