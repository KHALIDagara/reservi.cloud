require "test_helper"

class Ai::HandoffTest < ActiveSupport::TestCase
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
  end

  # ── basic handoff ────────────────────────────────────────────────

  test "handoff pauses an AI agent" do
    result = Ai::Handoff.call(agent: @agent)

    assert_equal "paused", result[:status]
    assert_equal "paused", @agent.reload.operational_status
  end

  test "handoff unclaims owned conversations" do
    # Fixtures already give @agent 2 conversations, plus we create 2 more
    base_count = @agent.owned_conversations.count
    assert_equal 2, base_count, "Expected 2 fixture owned conversations"

    conv1 = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Handoff1", email_address: "handoff1@example.com" },
      agent: @agent,
      content: "First conversation"
    )
    conv2 = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Handoff2", email_address: "handoff2@example.com" },
      agent: @agent,
      content: "Second conversation"
    )

    assert_equal 4, @agent.owned_conversations.count

    result = Ai::Handoff.call(agent: @agent)

    assert_equal 4, result[:unclaimed]
    assert_equal 0, @agent.reload.owned_conversations.count
    assert_nil conv1.reload.owner_id
    assert_nil conv2.reload.owner_id
  end

  test "handoff reports correct unclaimed count when agent already owns fixture conversations" do
    base_count = @agent.owned_conversations.count
    assert_equal 2, base_count, "Expected 2 fixture owned conversations"

    result = Ai::Handoff.call(agent: @agent)

    assert_equal "paused", result[:status]
    assert_equal base_count, result[:unclaimed]
    assert_equal 0, @agent.reload.owned_conversations.count
  end

  # ── preconditions ────────────────────────────────────────────────

  test "handoff raises for non-AI agent" do
    human_agent = agents(:alpha_bob_human)
    human_agent.update!(operational_status: "active")

    e = assert_raises(Reservi::Errors::OperationError) do
      Ai::Handoff.call(agent: human_agent)
    end
    assert_match /not AI/, e.message
  end

  test "handoff raises for non-operational agent" do
    @agent.update!(operational_status: "draft")

    e = assert_raises(Reservi::Errors::OperationError) do
      Ai::Handoff.call(agent: @agent)
    end
    assert_match /not operational/, e.message
  end

  test "handoff raises for archived agent" do
    @agent.update!(operational_status: "archived")

    e = assert_raises(Reservi::Errors::OperationError) do
      Ai::Handoff.call(agent: @agent)
    end
    assert_match /not operational/, e.message
  end

  # ── state idempotency ────────────────────────────────────────────

  test "handoff is idempotent on already-paused agent" do
    Ai::Handoff.call(agent: @agent)
    assert_equal "paused", @agent.reload.operational_status

    # Second call — agent is paused but still operational
    result = Ai::Handoff.call(agent: @agent)

    assert_equal "paused", result[:status]
    assert_equal 0, result[:unclaimed]
  end
end