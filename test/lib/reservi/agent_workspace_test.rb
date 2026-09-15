require "test_helper"

class Reservi::AgentWorkspaceTest < ActiveSupport::TestCase
  setup do
    @account      = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @human_agent  = agents(:alpha_alice_human)
  end

  # ── system context ─────────────────────────────────────────────

  test "includes system context" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    assert_equal "Alpha Garden",    workspace.dig(:system, :account_name)
    assert_equal "en",              workspace.dig(:system, :locale)
    assert_equal "UTC",             workspace.dig(:system, :timezone)
    assert_empty_or_blank          workspace.dig(:system, :capabilities)
  end

  test "system context returns nil role for human agent" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )
    assert_nil workspace.dig(:system, :agent_role)
  end

  test "system context includes agent_configuration role for AI agent" do
    ai_agent = Agent.create!(
      account: @account,
      kind: "ai",
      name: "AI Tester",
      operational_status: "active"
    )
    config = AgentConfiguration.create!(
      account:        @account,
      agent:          ai_agent,
      version_number: 1,
      status:         "published",
      role:           "customer-success",
      guidance_config: {},
      capability_config: {}
    )
    ai_agent.update!(agent_configuration: config)

    workspace = Reservi::AgentWorkspace.build(
      agent: ai_agent, conversation: @conversation
    )

    assert_equal "customer-success", workspace.dig(:system, :agent_role)
  end

  # ── process context ────────────────────────────────────────────

  test "includes process context with stage info" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    assert_equal "Intake",       workspace.dig(:process, :stage_label)
    assert_equal "stage_1",      workspace.dig(:process, :stage_key)
    assert_equal 1,              workspace.dig(:process, :stage_position)
    assert_equal({ "literal" => false }, workspace.dig(:process, :completion))
  end

  test "process context includes blocks" do
    stage = @conversation.current_stage
    stage.update!(blocks: [
      { "type" => "field", "key" => "city", "required" => true }
    ])

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    blocks = workspace.dig(:process, :blocks)
    assert_equal 1, blocks.length
    assert_equal "field", blocks.first.dig(:type)
    assert_equal "city",  blocks.first.dig(:key)
    assert_equal true,    blocks.first.dig(:required)
  end

  test "process context includes rules" do
    stage = @conversation.current_stage
    stage.update!(rules: [
      {
        "key" => "assign_if_cold",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }]
      }
    ])

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    rules = workspace.dig(:process, :rules)
    assert_equal 1, rules.length
    assert_equal "assign_if_cold", rules.first.dig(:key)
    assert_equal true,             rules.first.dig(:predicate, "literal")
    assert_equal ["assign"],       rules.first.dig(:actions)
  end

  test "process context includes stage details" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    process = workspace.dig(:process)
    assert process.key?(:stage_label)
    assert process.key?(:stage_key)
    assert process.key?(:blocks)
    assert process.key?(:completion)
  end

  # ── state context ──────────────────────────────────────────────

  test "state context includes customer profile" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    assert_equal "Wilma Customer",       workspace.dig(:state, :customer, :name)
    assert_equal "+15551234567",         workspace.dig(:state, :customer, :phone)
    assert_equal "wilma@example.com",    workspace.dig(:state, :customer, :email_address)
    assert_equal({},                     workspace.dig(:state, :customer, :custom_values))
  end

  test "state context includes conversation custom values" do
    @conversation.update!(custom_values: { "city" => "Marrakech", "budget" => "5000" })

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    assert_equal "Marrakech", workspace.dig(:state, :conversation, :custom_values, "city")
    assert_equal "5000",      workspace.dig(:state, :conversation, :custom_values, "budget")
  end

  test "state context includes conversation status and owner" do
    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation
    )

    assert_equal "active",        workspace.dig(:state, :conversation, :status)
    assert_equal "Alice Admin",   workspace.dig(:state, :conversation, :owner_name)
    assert_instance_of Integer,   workspace.dig(:state, :conversation, :revision)
  end

  test "state context includes item selections" do
    catalog = Catalog.create!(account: @account, title: "Services")
    item    = Item.create!(account: @account, catalog: catalog, title: "Garden Maintenance")

    ItemSelections::Select.call(
      conversation:     @conversation,
      item:             item,
      role_key:         "selected_service",
      actor_membership: nil
    )

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation.reload
    )

    items = workspace.dig(:state, :items)
    assert_equal 1, items.length
    assert_equal "selected_service",    items.first[:role]
    assert_equal "Garden Maintenance",  items.first[:item_title]
    assert_equal "Services",            items.first[:catalog_title]
  end

  test "state context includes appointments" do
    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key:     "pickup",
      starts_at:    1.day.from_now,
      ends_at:      1.day.from_now + 1.hour,
      timezone:     @account.timezone
    )

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation.reload
    )

    apps = workspace.dig(:state, :appointments)
    assert_equal 1, apps.length
    assert_equal "pickup",  apps.first[:role]
    assert_equal "pending", apps.first[:status]
    assert_not_nil          apps.first[:starts_at]
    assert_not_nil          apps.first[:ends_at]
  end

  # ── dialogue context ───────────────────────────────────────────

  test "dialogue context includes recent messages" do
    Messages::Create.call(
      conversation: @conversation,
      agent:        @human_agent,
      content:      "Hello, how can I help?",
      direction:    "outbound"
    )

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation.reload
    )

    messages = workspace.dig(:dialogue, :messages)
    refute_empty messages
    msg = messages.first
    assert_equal "Alice Admin",              msg[:from]
    assert_equal "human",                    msg[:from_kind]
    assert_equal "Hello, how can I help?",   msg[:content]
    assert_not_nil                           msg[:at]
  end

  test "dialogue context includes recent notes" do
    Notes::Create.call(
      conversation: @conversation,
      agent:        @human_agent,
      content:      "Internal note about customer"
    )

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation.reload
    )

    notes = workspace.dig(:dialogue, :notes)
    refute_empty notes
    note = notes.first
    assert_equal "Alice Admin",                 note[:from]
    assert_equal "Internal note about customer", note[:content]
    assert_not_nil                               note[:at]
  end

  test "dialogue context truncates long messages" do
    long_text = "x" * 600

    Messages::Create.call(
      conversation: @conversation,
      agent:        @human_agent,
      content:      long_text,
      direction:    "outbound"
    )

    workspace = Reservi::AgentWorkspace.build(
      agent: @human_agent, conversation: @conversation.reload
    )

    msg = workspace.dig(:dialogue, :messages).first
    assert_operator msg[:content].length, :<=, 503 # 500 + "..." from truncate
  end

  private

  def assert_empty_or_blank(obj)
    assert(obj.nil? || obj == {} || obj == [],
      "Expected nil or empty, got #{obj.inspect}")
  end
end