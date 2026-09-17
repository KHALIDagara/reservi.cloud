require "test_helper"

class Flows::EvaluateTest < ActiveSupport::TestCase
  setup do
    @conversation = conversations(:alpha_active)
    @stage = @conversation.current_stage
  end

  # ── Advancement ──────────────────────────────────────────────

  test "item selection completion advances after evaluation" do
    set_completion("exists", { "kind" => "item_selection", "key" => "requested_service" })
    catalog = @conversation.account.catalogs.create!(title: "Services")
    item = catalog.items.create!(account: @conversation.account, title: "Garden care")
    @conversation.item_selections.create!(
      account: @conversation.account, catalog:, item:,
      role_key: "requested_service", snapshot: { "title" => item.title }
    )

    result = Flows::Evaluate.call(conversation: @conversation)

    assert result[:advanced]
    assert @conversation.reload.process_status == "completed"
  end

  test "confirmed appointment completion advances after evaluation" do
    set_completion("eq", {
      "ref" => { "kind" => "appointment", "key" => "consultation", "attribute" => "status" },
      "value" => "confirmed"
    })
    @conversation.appointments.create!(
      account: @conversation.account, role_key: "consultation",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour,
      duration_minutes: 60, timezone: "UTC", status: "confirmed"
    )

    result = Flows::Evaluate.call(conversation: @conversation)

    assert result[:advanced]
    assert @conversation.reload.process_status == "completed"
  end

  # ── Failed rules block advancement ─────────────────────────

  test "failed rule action blocks advancement" do
    @stage.update!(completion: { "literal" => true },
                   rules: [
      {
        "key" => "fail_action",
        "predicate" => { "literal" => true },
        "actions" => [ { "type" => "send_message" } ]
      }
    ])

    result = Flows::Evaluate.call(conversation: @conversation)

    refute result[:advanced]
    assert_equal "active", @conversation.reload.process_status
    assert_match(/Blocked/, result[:explanation])
  end

  test "skipped rules do not block advancement" do
    @stage.update!(completion: { "literal" => true },
                   rules: [
      {
        "key" => "never_matches",
        "predicate" => { "literal" => false },
        "actions" => [ { "type" => "assign", "agent_id" => 1 } ]
      }
    ])

    result = Flows::Evaluate.call(conversation: @conversation)

    assert result[:advanced]
    assert @conversation.reload.process_status == "completed"
  end

  # ── Durability: repeated evaluation does not re-execute ─────

  test "repeated evaluation of a true rule does not re-execute actions" do
    @stage.update!(completion: { "literal" => false },
                   rules: [
      {
        "key" => "once_only",
        "predicate" => { "literal" => true },
        "actions" => [ { "type" => "assign", "agent_id" => agents(:alpha_bob_human).id } ]
      }
    ])

    first = Flows::Evaluate.call(conversation: @conversation)
    first_exec_count = @conversation.rule_executions.where(status: "executed").count

    second = Flows::Evaluate.call(conversation: @conversation)
    second_exec_count = @conversation.rule_executions.where(status: "executed").count

    assert_equal 1, first_exec_count
    assert_equal first_exec_count, second_exec_count,
      "Second evaluation should not have re-executed the already-executed rule"
  end

  private

  def set_completion(operator, config)
    @stage.update!(completion: config.is_a?(Hash) && config.keys == %w[eq ref value] ? config : { operator => config })
  end
end
