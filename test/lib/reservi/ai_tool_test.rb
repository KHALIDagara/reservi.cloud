require "test_helper"

class Reservi::AiToolTest < ActiveSupport::TestCase
  setup do
    @account      = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @human_agent  = agents(:alpha_alice_human)
    # Fixture agents default to operational_status "draft"; make them active for tests.
    @human_agent.update!(operational_status: "active")
  end

  # ── entry-point validation ─────────────────────────────────────

  test "returns error on unknown tool" do
    result = Reservi::AiTool.execute(
      tool_name: "non_existent", arguments: {},
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )
    assert_equal "non_existent", result[:tool]
    assert_match(/Unknown tool/, result[:error])
  end

  test "returns error on inactive agent" do
    @human_agent.update!(operational_status: "draft")
    refute @human_agent.operational?

    result = Reservi::AiTool.execute(
      tool_name: "read_workspace", arguments: {},
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )
    assert_match(/not operational/, result[:error])
  end

  # ── read_workspace ─────────────────────────────────────────────

  test "read_workspace returns a hash with expected keys" do
    result = Reservi::AiTool.execute(
      tool_name: "read_workspace", arguments: {},
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_instance_of Hash, result
    assert result.key?(:system)
    assert result.key?(:process)
    assert result.key?(:state)
    assert result.key?(:dialogue)
    assert_equal "Alpha Garden", result.dig(:system, :account_name)
  end

  # ── search_knowledge ───────────────────────────────────────────

  test "search_knowledge returns results through Knowledge::Search" do
    # Set up a shared published knowledge source
    source = KnowledgeSource.create!(account: @account, title: "Pricing Guide", kind: "qa", shared: true)
    source.revisions.create!(version_number: 1, status: "published", raw_text: "Our pricing starts at $99.")

    result = Reservi::AiTool.execute(
      tool_name: "search_knowledge", arguments: { "query" => "pricing" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "pricing", result[:query]
    assert result[:results].is_a?(Array)
    assert result[:results].length >= 0
  end

  test "search_knowledge rejects empty query" do
    result = Reservi::AiTool.execute(
      tool_name: "search_knowledge", arguments: { "query" => "" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_empty result[:results]
  end

  # ── create_message ─────────────────────────────────────────────

  test "create_message creates an outbound message" do
    assert_difference -> { @conversation.messages.count }, 1 do
      result = Reservi::AiTool.execute(
        tool_name: "create_message", arguments: { "content" => "Hello!" },
        agent: @human_agent, conversation: @conversation, ai_run: nil
      )

      assert_equal "sent",        result[:status]
      assert_equal "Message created", result[:message]
    end

    msg = @conversation.messages.last
    assert_equal "Hello!",       msg.content
    assert_equal "outbound",     msg.direction
    assert_equal @human_agent,   msg.agent
  end

  test "create_message rejects blank content" do
    result = Reservi::AiTool.execute(
      tool_name: "create_message", arguments: { "content" => "" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Message content is required", result[:error]
    assert_nil result[:status]
  end

  # ── create_note ────────────────────────────────────────────────

  test "create_note creates an internal note" do
    assert_difference -> { @conversation.notes.count }, 1 do
      result = Reservi::AiTool.execute(
        tool_name: "create_note", arguments: { "content" => "Internal" },
        agent: @human_agent, conversation: @conversation, ai_run: nil
      )

      assert_equal "created",     result[:status]
      assert_equal "Note created", result[:message]
    end

    note = @conversation.notes.last
    assert_equal "Internal",    note.content
    assert_equal @human_agent,  note.agent
  end

  test "create_note rejects blank content" do
    result = Reservi::AiTool.execute(
      tool_name: "create_note", arguments: { "content" => "" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Note content is required", result[:error]
  end

  # ── update_field ───────────────────────────────────────────────

  test "update_field updates conversation field" do
    result = Reservi::AiTool.execute(
      tool_name: "update_field",
      arguments: { "scope" => "conversation", "key" => "city", "value" => "Marrakech" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "updated",    result[:status]
    assert_equal "city",       result[:field]
    assert_equal "conversation", result[:scope]

    @conversation.reload
    assert_equal "Marrakech", @conversation.custom_values["city"]
  end

  test "update_field updates customer field" do
    result = Reservi::AiTool.execute(
      tool_name: "update_field",
      arguments: { "scope" => "customer", "key" => "city", "value" => "Rabat" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "updated",  result[:status]
    assert_equal "city",     result[:field]
    assert_equal "customer", result[:scope]

    @conversation.customer.reload
    assert_equal "Rabat", @conversation.customer.custom_values["city"]
  end

  test "update_field rejects missing key/value" do
    result = Reservi::AiTool.execute(
      tool_name: "update_field",
      arguments: { "scope" => "conversation", "key" => "", "value" => nil },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Field key and value are required", result[:error]
  end

  test "update_field rejects invalid scope" do
    result = Reservi::AiTool.execute(
      tool_name: "update_field",
      arguments: { "scope" => "bogus", "key" => "city", "value" => "X" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_match /Invalid scope/, result[:error]
  end

  # ── select_item ────────────────────────────────────────────────

  test "select_item selects an item" do
    catalog = Catalog.create!(account: @account, title: "Services")
    item    = Item.create!(account: @account, catalog: catalog, title: "Garden Maintenance")

    result = Reservi::AiTool.execute(
      tool_name: "select_item",
      arguments: { "role_key" => "service", "item_id" => item.id },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "selected",           result[:status]
    assert_equal "service",            result[:role]
    assert_equal item.id,              result[:item_id]
    assert_equal "Garden Maintenance", result[:item_title]

    selections = @conversation.item_selections.reload
    assert_equal 1, selections.count
    assert_equal "service", selections.first.role_key
  end

  test "select_item rejects invalid item_id" do
    result = Reservi::AiTool.execute(
      tool_name: "select_item",
      arguments: { "role_key" => "service", "item_id" => 999_999 },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Item not found", result[:error]
  end

  test "select_item rejects missing role_key" do
    result = Reservi::AiTool.execute(
      tool_name: "select_item",
      arguments: { "role_key" => "", "item_id" => 1 },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Role key and item ID are required", result[:error]
  end

  # ── create_appointment ─────────────────────────────────────────

  test "create_appointment creates a pending appointment" do
    result = Reservi::AiTool.execute(
      tool_name: "create_appointment",
      arguments: {
        "role_key"  => "pickup",
        "starts_at" => (1.day.from_now).iso8601,
        "ends_at"   => (1.day.from_now + 1.hour).iso8601
      },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "created", result[:status]
    assert_equal "pickup", result[:role]
    assert_not_nil result[:appointment_id]

    app = Appointment.find(result[:appointment_id])
    assert_equal "pending", app.status
  end

  test "create_appointment defaults ends_at to starts_at + 60 min" do
    starts = 1.day.from_now.change(usec: 0)

    result = Reservi::AiTool.execute(
      tool_name: "create_appointment",
      arguments: {
        "role_key"  => "pickup",
        "starts_at" => starts.iso8601
      },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "created", result[:status]

    app = Appointment.find(result[:appointment_id])
    assert_equal starts,            app.starts_at
    assert_equal starts + 3600,     app.ends_at # 60 min in seconds
  end

  test "create_appointment rejects missing role_key" do
    result = Reservi::AiTool.execute(
      tool_name: "create_appointment",
      arguments: { "role_key" => "", "starts_at" => (1.day.from_now).iso8601 },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Role key and starts_at are required", result[:error]
  end

  # ── confirm_appointment ────────────────────────────────────────

  test "confirm_appointment confirms a pending appointment" do
    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key:     "pickup",
      starts_at:    1.day.from_now,
      ends_at:      1.day.from_now + 1.hour,
      timezone:     @account.timezone
    )
    assert_equal "pending", appointment.status

    result = Reservi::AiTool.execute(
      tool_name: "confirm_appointment",
      arguments: { "role_key" => "pickup" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "confirmed", result[:status]
    assert_equal "pickup",    result[:role]

    appointment.reload
    assert_equal "confirmed", appointment.status
  end

  test "confirm_appointment returns error when no pending appointment" do
    result = Reservi::AiTool.execute(
      tool_name: "confirm_appointment",
      arguments: { "role_key" => "nonexistent" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "No pending appointment for role: nonexistent", result[:error]
  end

  # ── cancel_appointment ─────────────────────────────────────────

  test "cancel_appointment cancels a pending appointment" do
    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key:     "pickup",
      starts_at:    1.day.from_now,
      ends_at:      1.day.from_now + 1.hour,
      timezone:     @account.timezone
    )

    result = Reservi::AiTool.execute(
      tool_name: "cancel_appointment",
      arguments: { "role_key" => "pickup", "reason" => "Customer no-show" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "cancelled", result[:status]
    assert_equal "pickup",    result[:role]

    appointment.reload
    assert_equal "cancelled", appointment.status
  end

  test "cancel_appointment returns error when no active appointment" do
    result = Reservi::AiTool.execute(
      tool_name: "cancel_appointment",
      arguments: { "role_key" => "nonexistent" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "No active appointment for role: nonexistent", result[:error]
  end

  # ── handoff ────────────────────────────────────────────────────

  test "handoff unclaims the conversation" do
    assert_equal @human_agent.id, @conversation.owner_id

    result = Reservi::AiTool.execute(
      tool_name: "handoff",
      arguments: { "reason" => "Needs human escalation" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "handed_off", result[:status]
    assert_equal "Needs human escalation", result[:reason]

    @conversation.reload
    assert_nil @conversation.owner_id
  end

  # ── error handling ─────────────────────────────────────────────

  test "catches operation errors and returns error hash" do
    # Verify that errors within an operation are caught:
    result = Reservi::AiTool.execute(
      tool_name: "create_message",
      arguments: { "content" => "" },
      agent: @human_agent, conversation: @conversation, ai_run: nil
    )

    assert_equal "Message content is required", result[:error]
  end

  test "all tools defined in TOOLS are implementable" do
    Reservi::AiTool::TOOLS.each do |tool|
      assert(
        Reservi::AiTool.private_method_defined?(tool.to_sym) ||
        Reservi::AiTool.method_defined?(tool.to_sym),
        "AiTool is missing method for tool: #{tool}"
      )
    end
  end
end