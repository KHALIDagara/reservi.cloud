module Reservi
  # Maps AI tool calls to domain operations with proper authorization
  # and validation.  AI tools use the same operations as humans and Rules.
  #
  # Each tool is a named method that receives parsed arguments, executes
  # the matching domain operation, and returns a result hash.
  class AiTool
    TOOLS = %w[
      read_workspace search_knowledge create_message create_note
      update_field select_item create_appointment confirm_appointment
      cancel_appointment handoff
    ].freeze

    # ── entry point ───────────────────────────────────────────────

    def self.execute(tool_name:, arguments:, agent:, conversation:, ai_run:)
      new(tool_name:, arguments:, agent:, conversation:, ai_run:).execute
    end

    def initialize(tool_name:, arguments:, agent:, conversation:, ai_run:)
      @tool_name    = tool_name
      @arguments    = arguments || {}
      @agent        = agent
      @conversation = conversation
      @ai_run       = ai_run
    end

    def execute
      raise "Unknown tool: #{@tool_name}" unless TOOLS.include?(@tool_name)
      raise "AI agent is not operational" unless @agent.operational?

      send(@tool_name)
    rescue => e
      { error: e.message, tool: @tool_name }
    end

    private

    # ── read-only tools ───────────────────────────────────────────

    def read_workspace
      AgentWorkspace.build(agent: @agent, conversation: @conversation)
    end

    def search_knowledge
      query = @arguments["query"].to_s.strip
      return { results: [], query: query } if query.blank?

      Knowledge::Search.call(
        account: @conversation.account,
        agent:   @agent,
        query:   query
      )
    end

    # ── mutating tools ────────────────────────────────────────────

    def create_message
      content = @arguments["content"].to_s.strip
      return { error: "Message content is required" } if content.blank?

      Messages::Create.call(
        conversation: @conversation,
        agent:        @agent,
        content:      content,
        direction:    "outbound"
      )
      { status: "sent", message: "Message created" }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def create_note
      content = @arguments["content"].to_s.strip
      return { error: "Note content is required" } if content.blank?

      Notes::Create.call(
        conversation: @conversation,
        agent:        @agent,
        content:      content
      )
      { status: "created", message: "Note created" }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def update_field
      scope = @arguments["scope"] || "conversation"
      key   = @arguments["key"].to_s
      value = @arguments["value"]

      return { error: "Field key and value are required" } if key.blank? || value.nil?

      if scope == "conversation"
        ConversationFields::Update.call(
          conversation:    @conversation,
          actor_membership: nil,
          attributes:      { key => value }
        )
      elsif scope == "customer"
        customer = @conversation.customer
        return { error: "No customer associated with this conversation" } unless customer

        CustomerFields::Update.call(
          customer:         customer,
          actor_membership:  nil,
          attributes:       { key => value }
        )
      else
        return { error: "Invalid scope: #{scope}. Must be 'customer' or 'conversation'." }
      end
      { status: "updated", field: key, scope: scope }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def select_item
      role    = @arguments["role_key"].to_s
      item_id = @arguments["item_id"].to_i

      return { error: "Role key and item ID are required" } if role.blank? || item_id.zero?

      item = Item.find_by(id: item_id, account_id: @conversation.account_id)
      return { error: "Item not found" } unless item

      ItemSelections::Select.call(
        conversation:     @conversation,
        item:             item,
        role_key:         role,
        actor_membership: nil
      )
      { status: "selected", role: role, item_id: item.id, item_title: item.title }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def create_appointment
      role      = @arguments["role_key"].to_s
      starts_at = @arguments["starts_at"]
      ends_at   = @arguments["ends_at"]

      return { error: "Role key and starts_at are required" } if role.blank? || starts_at.blank?

      # Default ends_at to starts_at + 60 min if not provided
      starts_at = Time.zone.parse(starts_at.to_s) if starts_at.is_a?(String)
      return { error: "Invalid starts_at format" } unless starts_at

      ends_at = if ends_at.present?
        Time.zone.parse(ends_at.to_s)
      else
        starts_at + 60.minutes
      end
      return { error: "Invalid ends_at format" } unless ends_at

      appointment = Appointments::Create.call(
        conversation:     @conversation,
        role_key:         role,
        starts_at:        starts_at,
        ends_at:          ends_at,
        timezone:         @conversation.account.timezone,
        scheduled_agent:  @agent,
        purpose:          @arguments["purpose"]
      )
      { status: "created", role: role, appointment_id: appointment.id }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def confirm_appointment
      role = @arguments["role_key"].to_s
      return { error: "Role key is required" } if role.blank?

      appointment = @conversation.appointments.where(status: "pending").find_by(role_key: role)
      return { error: "No pending appointment for role: #{role}" } unless appointment

      Appointments::Confirm.call(appointment: appointment)
      { status: "confirmed", role: role }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def cancel_appointment
      role = @arguments["role_key"].to_s
      return { error: "Role key is required" } if role.blank?

      appointment = @conversation.appointments.where(role_key: role, status: %w[pending confirmed]).first
      return { error: "No active appointment for role: #{role}" } unless appointment

      reason = @arguments["reason"]
      Appointments::Cancel.call(appointment: appointment, reason: reason)
      { status: "cancelled", role: role }
    rescue => e
      { error: e.message, status: "failed" }
    end

    def handoff
      reason = @arguments["reason"].to_s

      Conversations::Unclaim.call(conversation: @conversation, agent: @agent)
      { status: "handed_off", reason: reason }
    rescue => e
      { error: e.message, status: "failed" }
    end
  end
end
