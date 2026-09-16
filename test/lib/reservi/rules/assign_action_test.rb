require "test_helper"

class Reservi::Rules::AssignActionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @alice = agents(:alpha_alice_human)
    @bob = agents(:alpha_bob_human)
    @context = { executing_agent: nil }

    # Start unowned
    @conversation.update!(owner: nil) if @conversation.owner_id.present?
  end

  test "assigns by agent_name" do
    result = Reservi::Rules::AssignAction.call(
      { "type" => "assign", "agent_name" => "Alice Admin" },
      conversation: @conversation, context: @context
    )

    assert_equal "assign", result[:type]
    assert_equal "assigned", result[:status]
    assert_equal @alice.id, result[:agent_id]

    @conversation.reload
    assert_equal @alice.id, @conversation.owner_id
  end

  test "assigns by agent_id" do
    result = Reservi::Rules::AssignAction.call(
      { "type" => "assign", "agent_id" => @bob.id },
      conversation: @conversation, context: @context
    )

    assert_equal "assigned", result[:status]
    @conversation.reload
    assert_equal @bob.id, @conversation.owner_id
  end

  test "skips when agent_name not found" do
    result = Reservi::Rules::AssignAction.call(
      { "type" => "assign", "agent_name" => "Nonexistent Agent" },
      conversation: @conversation, context: @context
    )

    assert_equal "skipped", result[:status]
    assert @conversation.unowned?
  end

  test "skips when conversation already has an owner" do
    @conversation.update!(owner: @alice)

    result = Reservi::Rules::AssignAction.call(
      { "type" => "assign", "agent_name" => "Bob Operator" },
      conversation: @conversation, context: @context
    )

    assert_equal "skipped", result[:status]

    @conversation.reload
    assert_equal @alice.id, @conversation.owner_id
  end

  test "assigns to team by team_name" do
    result = Reservi::Rules::AssignAction.call(
      { "type" => "assign", "team_name" => "General" },
      conversation: @conversation, context: @context
    )

    assert_equal "assign", result[:type]
    assert_equal "assigned", result[:status]

    @conversation.reload
    assert @conversation.owner_id.present?
  end
end
