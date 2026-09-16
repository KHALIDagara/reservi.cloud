require "test_helper"

class AiRuns::PreviewTest < ActiveSupport::TestCase
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
      customer_attributes: { name: "PreviewTest", email_address: "preview@example.com" },
      agent: @agent,
      content: "Hello, I need help"
    )
  end

  # ── basic preview ────────────────────────────────────────────────

  test "preview returns content without mutating conversation" do
    message_count_before = @conversation.messages.count

    result = AiRuns::Preview.call(
      agent: @agent, conversation: @conversation
    )

    assert result[:content].present?
    assert result[:preview] == true
    assert result[:workspace].present?
    assert_equal message_count_before, @conversation.reload.messages.count
  end

  test "preview returns proposed tool calls but never executes them" do
    custom_response = {
      "content"    => "I would send this message.",
      "tool_calls" => [
        { "name" => "create_message", "arguments" => { "content" => "Hi from preview" } }
      ],
      "usage"      => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }
    # Match on the preview-specific system_message
    key = "You are previewing actions for a Reservi conversation. Propose actions but do NOT execute them. Describe what you would do."

    adapter = Reservi::Ai::FakeAdapter.new(responses: { key => custom_response })

    assert_no_difference("Message.count") do
      AiRuns::Preview.call(
        agent: @agent, conversation: @conversation, adapter: adapter
      )
    end
  end

  test "preview never enqueues jobs" do
    assert_no_enqueued_jobs do
      AiRuns::Preview.call(
        agent: @agent, conversation: @conversation
      )
    end
  end

  test "preview includes workspace in result" do
    result = AiRuns::Preview.call(
      agent: @agent, conversation: @conversation
    )

    assert result[:workspace].present?
    assert result[:workspace].key?(:system)
    assert result[:workspace].key?(:state)
    assert result[:workspace].key?(:process)
    assert result[:workspace].key?(:dialogue)
  end

  test "preview includes usage information" do
    result = AiRuns::Preview.call(
      agent: @agent, conversation: @conversation
    )

    assert result[:usage].present?
    assert result[:usage].key?("prompt_tokens")
    assert result[:usage].key?("completion_tokens")
  end

  test "preview does not create any AiRun record" do
    assert_no_difference("AiRun.count") do
      AiRuns::Preview.call(
        agent: @agent, conversation: @conversation
      )
    end
  end

  test "preview logs the adapter call with tools" do
    adapter = Reservi::Ai::FakeAdapter.new

    AiRuns::Preview.call(
      agent: @agent, conversation: @conversation, adapter: adapter
    )

    assert_equal 1, adapter.calls.size
    assert adapter.calls.first[:prompt].present?
    assert adapter.calls.first[:tools].present?
  end
end