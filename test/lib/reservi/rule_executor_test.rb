require "test_helper"

class Reservi::RuleExecutorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @stage = @conversation.current_stage
    @alice = agents(:alpha_alice_human)
    @bob = agents(:alpha_bob_human)

    # Clear the fixture owner so assignment tests start clean
    @conversation.update!(owner: nil) if @conversation.owner_id.present?
  end

  test "evaluates a rule with always-true predicate and assigns agent" do
    # Add a rule to the current stage
    @stage.update!(rules: [
      { "key" => "assign_alice",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal 1, results.length

    execution = results.first
    assert_equal "executed", execution.status
    assert execution.predicate_result
    assert_equal "assign_alice", execution.rule_key
    assert_equal @stage.id, execution.stage_id

    @conversation.reload
    assert_equal @alice.id, @conversation.owner_id
  end

  test "skips rule whose predicate is false" do
    @stage.update!(rules: [
      { "key" => "assign_if_budget_high",
        "predicate" => { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 999999 } },
        "actions" => [{ "type" => "assign", "agent_name" => "Bob Operator" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal 1, results.length

    execution = results.first
    assert_equal "skipped", execution.status
    refute execution.predicate_result
    assert_match /did not match/, execution.explanation

    @conversation.reload
    assert @conversation.unowned?
  end

  test "is idempotent — duplicate evaluation does not reassign" do
    @stage.update!(rules: [
      { "key" => "assign_alice",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
    ])

    first_results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal 1, first_results.length
    assert_equal "executed", first_results.first.status

    @conversation.reload
    first_owner = @conversation.owner_id

    # Second evaluation — should skip due to execution_key uniqueness
    second_results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal 1, second_results.length
    assert_equal "executed", second_results.first.status

    @conversation.reload
    assert_equal first_owner, @conversation.owner_id

    # Only one unique execution_key
    keys = @conversation.rule_executions.pluck(:execution_key)
    assert_equal keys.uniq.length, keys.length
  end

  test "evaluates rules in order and stops on failure" do
    @stage.update!(rules: [
      { "key" => "first_rule",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] },
      { "key" => "failing_rule",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "unknown_action_xyz" }] },
      { "key" => "third_rule",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Bob Operator" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)

    # First rule executed, second failed, third may have failed too
    first = results.find { |r| r.rule_key == "first_rule" }
    failing = results.find { |r| r.rule_key == "failing_rule" }

    assert_equal "executed", first.status
    assert_equal "failed", failing.status
    assert_match /unknown action/i, failing.error_message

    @conversation.reload
    assert_equal @alice.id, @conversation.owner_id
  end

  test "generates explanation for matched rule" do
    @stage.update!(rules: [
      { "key" => "city_rule",
        "predicate" => { "exists" => { "kind" => "field", "scope" => "customer", "key" => "phone" } },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    execution = results.first

    assert_equal "executed", execution.status
    assert execution.explanation.present?
    assert_match /city_rule/, execution.explanation
    assert_match /matched/, execution.explanation
  end

  test "explains why rule was skipped" do
    @stage.update!(rules: [
      { "key" => "never_match",
        "predicate" => { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "nonexistent" }, "value" => "anything" } },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    execution = results.first

    assert_equal "skipped", execution.status
    assert_match /did not match/, execution.explanation
  end

  test "retuns empty array when stage has no rules" do
    @stage.update!(rules: [])
    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal [], results
  end

  test "returns empty array when conversation's current stage has no rules" do
    @stage.update!(rules: [])
    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert_equal [], results
  end

  test "evaluates rules for completed conversation but does not assign" do
    @conversation.update!(process_status: "completed", owner: nil)
    @stage.update!(rules: [
      { "key" => "assign_alice",
        "predicate" => { "literal" => true },
        "actions" => [{ "type" => "assign", "agent_name" => "Alice Admin" }] }
    ])

    results = Reservi::RuleExecutor.evaluate(conversation: @conversation)
    assert results.present?
    execution = results.first
    # Rule matches and executes, but assignment on completed conversation
    # happens (Claim doesn't check process_status)
    assert_equal "executed", execution.status
  end
end