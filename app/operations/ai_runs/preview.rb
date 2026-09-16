module AiRuns
  # Private preview: proposes actions without mutating domain state.
  #
  # Builds a workspace snapshot and calls the AI adapter with a
  # preview-oriented system message, but **never** executes tool
  # calls against domain operations.  Returns the proposed actions
  # for human review or automated filtering.
  class Preview
    def self.call(agent:, conversation:, adapter: nil)
      new(agent:, conversation:, adapter:).call
    end

    def initialize(agent:, conversation:, adapter: nil)
      @agent        = agent
      @conversation = conversation
      @adapter      = adapter || Reservi::Ai::FakeAdapter.new
    end

    def call
      workspace = Reservi::AgentWorkspace.build(
        agent:        @agent,
        conversation: @conversation
      )

      tools          = Reservi::AiToolSchema.function_definitions(agent: @agent)
      system_message = "You are previewing actions for a Reservi conversation. " \
        "Propose actions but do NOT execute them. Describe what you would do."

      response = @adapter.generate(
        prompt:         JSON.pretty_generate(workspace),
        system_message: system_message,
        tools:          tools
      )

      {
        content:             response["content"],
        proposed_tool_calls: response["tool_calls"] || [],
        workspace:           workspace,
        usage:               response["usage"] || {},
        preview:             true
      }
    end
  end
end