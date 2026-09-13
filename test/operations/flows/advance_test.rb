require "test_helper"

class Flows::AdvanceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
  end

  test "does not advance when completion predicate is false" do
    # alpha_stage1 has literal false completion
    result = Flows::Advance.call(conversation: @conversation)
    refute result[:advanced]
    assert_nil result[:transition]
    refute result[:complete]
    assert_equal "Literal false", result[:explanation][:reason]
  end

  test "advances to next stage when predicate becomes true" do
    stage = @conversation.current_stage
    # Create a second stage to advance to
    second_stage = @conversation.flow_version.stages.create!(
      key: "stage_2",
      label: "Review",
      position: 2,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    stage.update!(completion: { "literal" => true })

    result = Flows::Advance.call(conversation: @conversation)
    assert result[:advanced]
    assert_instance_of StageTransition, result[:transition]
    refute result[:complete]

    @conversation.reload
    assert_equal second_stage.id, @conversation.current_stage_id
    assert @conversation.last_activity_at.present?
    assert @conversation.active?
  end

  test "completes conversation when advancing from terminal stage" do
    stage = @conversation.current_stage
    # Make this the only stage — no next stage means terminal
    stage.update!(completion: { "literal" => true })

    result = Flows::Advance.call(conversation: @conversation)
    assert result[:advanced]
    assert result[:complete]

    @conversation.reload
    assert_equal "completed", @conversation.process_status
    assert_nil @conversation.owner_id
    refute @conversation.attention?
  end

  test "is idempotent — double call does not create extra transitions" do
    stage = @conversation.current_stage
    stage.update!(completion: { "literal" => true })

    first = Flows::Advance.call(conversation: @conversation)
    assert first[:advanced]

    @conversation.reload

    second = Flows::Advance.call(conversation: @conversation)
    refute second[:advanced]  # already completed or advanced
  end

  test "does not advance cancelled conversation" do
    cancelled = conversations(:alpha_cancelled)
    result = Flows::Advance.call(conversation: cancelled)
    refute result[:advanced]
    refute result[:complete]
  end

  test "creates transition record with correct data" do
    stage = @conversation.current_stage
    stage.update!(completion: { "literal" => true })

    result = Flows::Advance.call(conversation: @conversation)
    transition = result[:transition]

    assert_equal @conversation.id, transition.conversation_id
    assert_equal stage.id, transition.from_stage_id
    assert_nil transition.to_stage  # no second stage, terminal
    assert_equal "completion", transition.reason
    assert transition.entry_identity.present?
    assert_equal @conversation.customer.profile_revision, transition.input_revisions["profile_revision"]
  end

  test "advances through multiple stages sequentially" do
    stage1 = @conversation.current_stage
    stage1.update!(completion: { "literal" => true })

    stage2 = @conversation.flow_version.stages.create!(
      key: "stage_2",
      label: "Review",
      position: 2,
      blocks: [],
      rules: [],
      completion: { "literal" => true }
    )

    # Advance from stage 1 -> stage 2
    result1 = Flows::Advance.call(conversation: @conversation)
    assert result1[:advanced]
    @conversation.reload
    assert_equal stage2.id, @conversation.current_stage_id

    # Advance from stage 2 -> completed
    result2 = Flows::Advance.call(conversation: @conversation)
    assert result2[:advanced]
    assert result2[:complete]
    @conversation.reload
    assert_equal "completed", @conversation.process_status
  end

  test "fires rules on the target stage after advancement" do
    stage = @conversation.current_stage
    alice = agents(:alpha_alice_human)

    target_stage = @conversation.flow_version.stages.create!(
      key: "target_with_rules",
      label: "Target",
      position: 2,
      blocks: [],
      rules: [
        { "key" => "auto_assign",
          "predicate" => { "literal" => true },
          "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
      ],
      completion: { "literal" => false }
    )
    stage.update!(completion: { "literal" => true })

    result = Flows::Advance.call(conversation: @conversation)
    assert result[:advanced]

    @conversation.reload
    assert_equal target_stage.id, @conversation.current_stage_id
    assert_equal alice.id, @conversation.owner_id

    # Verify RuleExecution was recorded for the target stage
    executions = @conversation.rule_executions
    assert_equal 1, executions.length
    assert_equal "auto_assign", executions.first.rule_key
    assert_equal "executed", executions.first.status
  end

  test "does not fire rules on terminal completion (no next stage)" do
    stage = @conversation.current_stage
    stage.update!(
      completion: { "literal" => true },
      rules: [
        { "key" => "final_rule",
          "predicate" => { "literal" => true },
          "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
      ]
    )

    result = Flows::Advance.call(conversation: @conversation)
    assert result[:advanced]
    assert result[:complete]

    @conversation.reload
    assert_equal "completed", @conversation.process_status
    # Owner should be nil (terminal completion clears it)
    assert_nil @conversation.owner_id
  end

  test "does not advance when not active" do
    stage = @conversation.current_stage
    stage.update!(completion: { "literal" => true })

    # Make the conversation completed
    @conversation.update!(process_status: "completed")

    result = Flows::Advance.call(conversation: @conversation)
    refute result[:advanced]
  end
end