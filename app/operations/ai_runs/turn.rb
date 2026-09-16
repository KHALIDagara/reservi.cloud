module AiRuns
  # The main AI execution loop.
  #
  # From the admitted run:
  #  1. Validates the run is active (admitted or evaluating).
  #  2. Transitions to "evaluating".
  #  3. Builds the workspace snapshot for the agent.
  #  4. Retrieves available function definitions.
  #  5. Calls the AI adapter with the workspace as context.
  #  6. Executes any tool calls from the response against domain operations.
  #  7. Returns content, tool results, usage, and the snapshot used.
  class Turn
    def self.call(ai_run:, adapter: nil)
      new(ai_run:, adapter:).call
    end

    def initialize(ai_run:, adapter: nil)
      @ai_run  = ai_run
      @adapter = adapter || Reservi::Ai::FakeAdapter.new
    end

    def call
      raise Reservi::Errors::OperationError, "Run is not active" unless @ai_run.active?

      @ai_run.transition_to!("evaluating") unless @ai_run.status == "evaluating"

      workspace = Reservi::AgentWorkspace.build(
        agent:        @ai_run.agent,
        conversation: @ai_run.conversation
      )

      tools          = Reservi::AiToolSchema.function_definitions(agent: @ai_run.agent)
      system_message = build_system_message(workspace)
      prompt         = build_prompt(workspace)

      response = @adapter.generate(
        prompt:         prompt,
        system_message: system_message,
        tools:          tools
      )

      tool_results = execute_tool_calls(response["tool_calls"] || [])

      usage = response["usage"] || {}
      @ai_run.update!(usage_json: usage)

      {
        content:      response["content"],
        tool_results: tool_results,
        usage:        usage,
        workspace:    workspace
      }
    end

    private

    def build_system_message(workspace)
      stage = workspace.dig(:process, :stage_label) || "Unknown"

      "You are an AI assistant for Reservi. The current stage is: #{stage}. " \
        "Use the available tools to help move the conversation forward. " \
        "Read the workspace to understand the current state before acting."
    end

    def build_prompt(workspace)
      JSON.pretty_generate(workspace)
    end

    def execute_tool_calls(tool_calls)
      tool_calls.map do |tc|
        name      = tc.is_a?(Hash) ? (tc["name"] || tc[:name]) : nil
        arguments = tc.is_a?(Hash) ? (tc["arguments"] || tc[:arguments]) : nil

        next { error: "Invalid tool call format" } unless name

        Reservi::AiTool.execute(
          tool_name:    name,
          arguments:    arguments,
          agent:        @ai_run.agent,
          conversation: @ai_run.conversation,
          ai_run:       @ai_run
        )
      end
    end
  end
end