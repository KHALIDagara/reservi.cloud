require "test_helper"

class Reservi::AiToolSchemaFilterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @lina = agents(:alpha_lina_ai) # has published config with full capabilities
    @scheduler = agents(:alpha_scheduler_ai) # draft config with limited capabilities
  end

  test "returns all tools when agent has no config (backward compat)" do
    agent = Agent.new(kind: "ai")
    tools = Reservi::AiToolSchema.function_definitions(agent: agent)
    assert_operator tools.size, :>, 5
  end

  test "filters tools by capability_config" do
    tools = Reservi::AiToolSchema.function_definitions(agent: @lina)
    tool_names = tools.map { |t| t.dig(:function, :name) }

    # Lina has: reply, update_fields, select_items, create_appointments, search_knowledge, add_notes, handoff
    # but NOT cancel_appointments
    assert_includes tool_names, "read_workspace"
    assert_includes tool_names, "create_message"
    assert_includes tool_names, "handoff"
    assert_not_includes tool_names, "cancel_appointment"
  end

  test "limited capability agent gets fewer tools" do
    tools = Reservi::AiToolSchema.function_definitions(agent: @scheduler)
    tool_names = tools.map { |t| t.dig(:function, :name) }

    assert_includes tool_names, "read_workspace"
    assert_includes tool_names, "create_message" # reply = true
    assert_includes tool_names, "create_appointment" # create_appointments = true
    assert_includes tool_names, "cancel_appointment" # cancel_appointments = true
    assert_not_includes tool_names, "handoff"         # handoff = false
    assert_not_includes tool_names, "select_item"     # select_items = false
    assert_not_includes tool_names, "update_field"    # update_fields = false
  end
end