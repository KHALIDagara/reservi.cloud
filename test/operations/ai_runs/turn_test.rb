require "test_helper"

class AiRuns::TurnTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)

    @agent = agents(:alpha_alice_human)
    @agent.update!(kind: "ai", membership_id: nil, operational_status: "active")

    @agent_config = AgentConfiguration.create!(
      account: @account,
      agent: @agent,
      version_number: 1,
      status: "published",
      role: "test_role",
      provider_type: "fake",
      model_identifier: "fake-v1"
    )
    @agent.update!(agent_configuration_id: @agent_config.id)

    @conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "TurnTest", email_address: "turn@example.com" },
      agent: @agent,
      content: "Hello, I need help"
    )

    @admit_result = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "test"
    )
    @ai_run = AiRun.find(@admit_result[:ai_run_id])
  end

  # ── basic execution ──────────────────────────────────────────────

  test "turn executes successfully and transitions to evaluating" do
    result = AiRuns::Turn.call(ai_run: @ai_run)

    assert result[:content].present?
    assert_equal "evaluating", @ai_run.reload.status
    assert @ai_run.started_at.present?
  end

  test "turn returns workspace in result" do
    result = AiRuns::Turn.call(ai_run: @ai_run)

    assert result[:workspace].present?
    assert result[:workspace].key?(:system)
    assert result[:workspace].key?(:state)
    assert result[:workspace].key?(:process)
    assert result[:workspace].key?(:dialogue)
  end

  test "turn updates usage_json on the run" do
    AiRuns::Turn.call(ai_run: @ai_run)

    @ai_run.reload
    assert @ai_run.usage_json.present?
    assert @ai_run.usage_json.key?("prompt_tokens")
    assert @ai_run.usage_json.key?("completion_tokens")
  end

  test "turn uses a custom adapter when provided" do
    custom_response = {
      "content"    => "Custom response from test adapter",
      "tool_calls" => [],
      "usage"      => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)

    assert_equal "Custom response from test adapter", result[:content]
    assert_equal 1, adapter.calls.size
  end

  test "turn logs the adapter call with tools and prompt" do
    adapter = Reservi::Ai::FakeAdapter.new

    AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)

    assert_equal 1, adapter.calls.size
    assert adapter.calls.first[:prompt].present?
    assert adapter.calls.first[:system_message].present?
    assert adapter.calls.first[:tools].present?
  end

  # ── tool call execution ──────────────────────────────────────────

  test "turn executes tool calls from the adapter response" do
    custom_response = {
      "content"    => "I will send a message now.",
      "tool_calls" => [
        { "name" => "create_message", "arguments" => { "content" => "Hello from AI" } }
      ],
      "usage"      => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    assert_difference("Message.count", 1) do
      result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)
      assert_equal 1, result[:tool_results].size
      assert_equal "sent", result[:tool_results].first[:status]
    end

    msg = @conversation.messages.last
    assert_equal "Hello from AI", msg.content
    assert_equal "outbound", msg.direction
  end

  test "turn handles empty tool_calls gracefully" do
    custom_response = {
      "content"    => "No tools needed.",
      "tool_calls" => [],
      "usage"      => { "prompt_tokens" => 5, "completion_tokens" => 3, "total_tokens" => 8 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)
    assert_equal [], result[:tool_results]
  end

  test "turn handles nil tool_calls gracefully" do
    custom_response = {
      "content"    => "No tools at all.",
      "usage"      => { "prompt_tokens" => 5, "completion_tokens" => 3, "total_tokens" => 8 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)
    assert_equal [], result[:tool_results]
  end

  test "turn captures a tool error when tool execution fails" do
    custom_response = {
      "content"    => "I will try an unknown tool.",
      "tool_calls" => [
        { "name" => "nonexistent_tool", "arguments" => {} }
      ],
      "usage"      => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)

    assert_equal 1, result[:tool_results].size
    assert result[:tool_results].first[:error].present?
  end

  test "turn handles invalid tool call format gracefully" do
    custom_response = {
      "content"    => "Malformed call.",
      "tool_calls" => [
        { "garbage" => true }
      ],
      "usage"      => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { system_message_key => custom_response })

    result = AiRuns::Turn.call(ai_run: @ai_run, adapter: adapter)

    assert_equal 1, result[:tool_results].size
    assert_equal "Invalid tool call format", result[:tool_results].first[:error]
  end

  private

  def system_message_key
    stage = @conversation.current_stage
    "You are an AI assistant for Reservi. The current stage is: #{stage&.label || 'Unknown'}. " \
      "Use the available tools to help move the conversation forward. " \
      "Read the workspace to understand the current state before acting."
  end

  # ── preconditions ────────────────────────────────────────────────

  test "turn on non-active run raises error" do
    @ai_run.transition_to!("completed")
    @ai_run.reload

    e = assert_raises(Reservi::Errors::OperationError) do
      AiRuns::Turn.call(ai_run: @ai_run)
    end
    assert_match /not active/, e.message
  end

  test "turn can be called from evaluating state (re-entry)" do
    AiRuns::Turn.call(ai_run: @ai_run)
    assert_equal "evaluating", @ai_run.reload.status

    # Second turn should still work from evaluating state
    result = AiRuns::Turn.call(ai_run: @ai_run)
    assert result[:content].present?
  end
end