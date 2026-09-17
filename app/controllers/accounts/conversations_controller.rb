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
      render layout: false
    end

    def update_field
      value = typed_field_value(scope: "conversation", key: params[:key], value: params[:value])
      ConversationFields::Update.call(
        conversation: @conversation,
        actor_membership: current_membership,
        attributes: { params[:key] => value }
      )
      redirect_to account_conversation_path(current_account, @conversation), notice: "Field updated."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def update_customer_field
      value = typed_field_value(scope: "customer", key: params[:key], value: params[:value])
      CustomerFields::Update.call(
        customer: @conversation.customer,
        actor_membership: current_membership,
        attributes: { params[:key] => value }
      )
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Customer field updated."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def reassign
      agent = current_account.agents.active.find_by(id: params[:agent_id])
      return render json: { error: "Agent not found" }, status: :not_found unless agent

      if @conversation.owner_id.present?
        Conversations::Unclaim.call(conversation: @conversation, agent: @conversation.owner)
      end
      Conversations::Claim.call(conversation: @conversation, agent: agent)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Conversation assigned."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def create_appointment
      validate_appointment_role!(params[:role_key])
      starts_at = parse_appointment_time!(params[:starts_at])

      Appointments::Create.call(
        conversation: @conversation,
        role_key: params[:role_key],
        starts_at:,
        ends_at: starts_at + 1.hour,
        timezone: current_account.timezone,
        scheduled_agent: current_membership.agent
      )
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Appointment added."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def confirm_appointment
      appointment = current_account.appointments.find_by(
        id: params[:appointment_id],
        conversation_id: @conversation.id
      )
      return render json: { error: "Appointment not found" }, status: :not_found unless appointment

      validate_appointment_role!(appointment.role_key)
      Appointments::Confirm.call(appointment: appointment)
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Appointment confirmed."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def cancel_appointment
      appointment = current_account.appointments.find_by(
        id: params[:appointment_id],
        conversation_id: @conversation.id
      )
      return render json: { error: "Appointment not found" }, status: :not_found unless appointment

      validate_appointment_role!(appointment.role_key)
      Appointments::Cancel.call(appointment: appointment)
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Appointment cancelled."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
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

    def typed_field_value(scope:, key:, value:)
      definition = current_account.field_definitions.active
        .where(scope:)
        .find_by("key = :key OR built_in_binding = :key", key: key)
      unless definition
        raise Reservi::Errors::OperationError, "That field is not configured."
      end
      unless Array(@conversation.current_stage&.blocks).any? { |block| block["type"] == "field" && block["key"] == definition.key }
        raise Reservi::Errors::OperationError, "That field is not available in the current stage."
      end
      return nil if value.blank? && definition.field_type != "multi_choice"

      case definition.field_type
      when "number"
        number = BigDecimal(value.to_s)
        number.frac.zero? ? number.to_i : number.to_f
      when "boolean"
        ActiveModel::Type::Boolean.new.cast(value)
      when "multi_choice"
        Array(value).reject(&:blank?)
      else
        value
      end
    rescue ArgumentError
      value
    end

    def validate_appointment_role!(role_key)
      available = Array(@conversation.current_stage&.blocks).any? do |block|
        block["type"] == "appointment" && block["role_key"] == role_key
      end
      return if available

      raise Reservi::Errors::OperationError, "That appointment is not available in the current stage."
    end

    def parse_appointment_time!(raw_value)
      raw = raw_value.to_s
      raise Reservi::Errors::OperationError, "Choose an appointment time." if raw.blank?

      local = Time.strptime(raw, "%Y-%m-%dT%H:%M")
      zone = ActiveSupport::TimeZone[current_account.timezone]
      periods = zone.tzinfo.periods_for_local(local)
      if periods.size != 1
        raise Reservi::Errors::OperationError, "Choose an unambiguous local time."
      end

      zone.local(local.year, local.month, local.day, local.hour, local.min)
    rescue ArgumentError, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
      raise Reservi::Errors::OperationError, "Choose a valid appointment time."
    end

    def load_fields
      field_keys = @stage_blocks.select { |b| b["type"] == "field" }.map { |b| b["key"] }.compact
      return if field_keys.empty?

      @field_definitions = current_account.field_definitions.active
        .where(scope: %w[customer conversation], key: field_keys)
        .ordered

      # Split by scope, merge current values
      @customer_fields = {}
      @conversation_fields = {}
      @field_definitions.each do |fd|
        key = fd.key
        if fd.scope == "customer"
          value = fd.built_in_binding.present? ? @conversation.customer.public_send(fd.built_in_binding) : @conversation.customer.custom_values[key]
          @customer_fields[key] = { definition: fd, value: }
        else
          @conversation_fields[key] = { definition: fd, value: @conversation.custom_values[key] }
        end
      end
    end

    def load_catalogs
      catalog_blocks = @stage_blocks.select { |b| b["type"] == "catalog" && b["catalog_key"].present? }
      return if catalog_blocks.empty?

      catalog_keys = catalog_blocks.map { |b| b["catalog_key"] }.uniq
      @catalogs = current_account.catalogs.active
        .where("LOWER(title) IN (?)", catalog_keys.map(&:downcase))
        .includes(:items)
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
