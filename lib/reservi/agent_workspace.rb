module Reservi
  # Pure reader (no mutations) that builds a structured snapshot of everything
  # an AI agent needs to understand the current conversation state.
  #
  # Actor-scoped snapshot:
  #   system     – account/timezone/locale, agent role & capabilities
  #   process    – current Flow/Stage with blocks, completion, and rules
  #   state      – customer profile, conversation fields, item selections, appointments
  #   dialogue   – bounded recent messages and internal notes
  class AgentWorkspace
    def self.build(agent:, conversation:)
      new(agent:, conversation:).build
    end

    def initialize(agent:, conversation:)
      @agent = agent
      @conversation = conversation
    end

    def build
      {
        system:    system_context,
        process:   process_context,
        state:     state_context,
        dialogue:  dialogue_context
      }
    end

    private

    # ── system ────────────────────────────────────────────────────

    def system_context
      {
        account_name: @conversation.account.name,
        locale:       @conversation.account.locale,
        timezone:     @conversation.account.timezone,
        agent_role:   agent_role,
        capabilities: @agent.capabilities
      }
    end

    # ── process ───────────────────────────────────────────────────

    def process_context
      stage = @conversation.current_stage
      return {} unless stage

      {
        flow_name:     @conversation.flow_version&.flow&.name,
        stage_label:   stage.label,
        stage_key:     stage.key,
        stage_position: stage.position,
        blocks:        (stage.blocks || []).map { |b| block_summary(b) },
        completion:    stage.completion,
        rules:         (stage.rules || []).map { |r| rule_summary(r) }
      }
    end

    # ── state ─────────────────────────────────────────────────────

    def state_context
      customer = @conversation.customer

      {
        customer: {
          name:          customer&.name,
          phone:         customer&.phone,
          email_address: customer&.email_address,
          custom_values: customer&.custom_values || {}
        },
        conversation: {
          custom_values: @conversation.custom_values || {},
          owner_name:    @conversation.owner&.name,
          team_name:     @conversation.team&.name,
          status:        @conversation.process_status,
          revision:      @conversation.revision
        },
        items:        item_selections_context,
        appointments: appointments_context
      }
    end

    def item_selections_context
      @conversation.item_selections.map { |s|
        {
          role:          s.role_key,
          item_title:    s.snapshot&.dig("title"),
          catalog_title: s.catalog&.title
        }
      }
    end

    def appointments_context
      @conversation.appointments.active.map { |a|
        {
          role:      a.role_key,
          status:    a.status,
          starts_at: a.starts_at,
          ends_at:   a.ends_at
        }
      }
    end

    # ── dialogue ──────────────────────────────────────────────────

    def dialogue_context
      messages = @conversation.messages.order(created_at: :asc).last(20).map { |m|
        {
          from:      m.agent&.name || "Customer",
          from_kind: m.agent&.kind,
          content:   m.content&.truncate(500),
          at:        m.created_at
        }
      }

      notes = @conversation.notes.order(created_at: :asc).last(10).map { |n|
        {
          from:    n.agent&.name,
          content: n.content&.truncate(300),
          at:      n.created_at
        }
      }

      { messages: messages, notes: notes }
    end

    # ── helpers ───────────────────────────────────────────────────

    def block_summary(block)
      {
        type:       block["type"],
        key:        block["key"],
        required:   block["required"],
        catalog_key: block["catalog_key"],
        role_key:   block["role_key"]
      }.compact
    end

    def rule_summary(rule)
      {
        key:       rule["key"],
        predicate: rule["predicate"],
        actions:   (rule["actions"] || []).map { |a| a["type"] }
      }
    end

    def agent_role
      return nil unless @agent.kind == "ai"
      @agent.agent_configuration&.role
    end
  end
end
