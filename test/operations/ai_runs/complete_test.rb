require "test_helper"

class AiRuns::CompleteTest < ActiveSupport::TestCase
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
      customer_attributes: { name: "CompleteTest", email_address: "complete@example.com" },
      agent: @agent,
      content: "Initial message"
    )

    @admit_result = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "test"
    )
    @ai_run = AiRun.find(@admit_result[:ai_run_id])
  end

  # ── successful completion ───────────────────────────────────────

  test "complete transitions admitted to completed" do
    result = AiRuns::Complete.call(ai_run: @ai_run, status: "completed")
    assert_equal "completed", result.status
    assert result.completed_at.present?
  end

  test "complete with status failed transitions admitted to failed" do
    result = AiRuns::Complete.call(ai_run: @ai_run, status: "failed")
    assert_equal "failed", result.status
    assert result.failed_at.present?
  end

  test "complete transitions evaluating to completed" do
    @ai_run.transition_to!("evaluating")
    @ai_run.reload

    result = AiRuns::Complete.call(ai_run: @ai_run, status: "completed")
    assert_equal "completed", result.status
  end

  # ── error cases ─────────────────────────────────────────────────

  test "complete on already-completed run raises error" do
    AiRuns::Complete.call(ai_run: @ai_run, status: "completed")

    e = assert_raises(Reservi::Errors::OperationError) do
      AiRuns::Complete.call(ai_run: @ai_run, status: "completed")
    end
    assert_match /not active/, e.message
  end

  test "complete with invalid final status raises error" do
    e = assert_raises(ArgumentError) do
      AiRuns::Complete.call(ai_run: @ai_run, status: "bogus")
    end
    assert_match /Invalid final status/, e.message
  end

  test "complete on non-active run raises error" do
    @ai_run.transition_to!("completed")
    @ai_run.reload

    e = assert_raises(Reservi::Errors::OperationError) do
      AiRuns::Complete.call(ai_run: @ai_run, status: "completed")
    end
    assert_match /not active/, e.message
  end

  # ── race safety ─────────────────────────────────────────────────

  test "concurrent complete calls succeed exactly once" do
    results = []
    threads = 3.times.map do
      Thread.new do
        begin
          AiRuns::Complete.call(ai_run: @ai_run, status: "completed")
          :ok
        rescue ActiveRecord::StaleObjectError
          :race
        end
      end
    end
    results = threads.map(&:value)

    ok_count  = results.count(:ok)
    race_count = results.count(:race)

    assert_equal 1, ok_count, "Expected exactly one completion to succeed"
    assert_equal 2, race_count, "Expected two race losers"
    assert_equal "completed", @ai_run.reload.status
  end
end