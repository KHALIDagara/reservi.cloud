require "test_helper"

class Reservi::AiToolCapabilityTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @lina = agents(:alpha_lina_ai)
    @lina.update!(operational_status: "active")
  end

  test "blocks tool when capability is disabled" do
    # Lina has cancel_appointments: false in her config
    result = Reservi::AiTool.execute(
      tool_name: "cancel_appointment",
      arguments: { "role_key" => "test" },
      agent: @lina,
      conversation: @conversation,
      ai_run: nil
    )
    assert result[:error].present?
    assert_match(/not permitted/, result[:error])
  end

  test "allows tool when capability is enabled" do
    result = Reservi::AiTool.execute(
      tool_name: "create_message",
      arguments: { "content" => "Hello!" },
      agent: @lina,
      conversation: @conversation,
      ai_run: nil
    )
    assert_equal "sent", result[:status]
  end

  test "allows tool when agent has no capability config (backward compat)" do
    agent = agents(:alpha_alice_human)
    agent.update!(operational_status: "active")

    result = Reservi::AiTool.execute(
      tool_name: "create_message",
      arguments: { "content" => "Hello!" },
      agent: agent,
      conversation: @conversation,
      ai_run: nil
    )
    assert_equal "sent", result[:status]
  end
end