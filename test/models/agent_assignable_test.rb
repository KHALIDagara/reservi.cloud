require "test_helper"

class AgentAssignableTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)

    # Set up test human agent
    @human_agent = agents(:alpha_alice_human)
    @human_agent.update!(operational_status: "active")

    # AI agents from fixtures
    @lina = agents(:alpha_lina_ai)
    @scheduler = agents(:alpha_scheduler_ai)
  end

  # ── active_for_work? ─────────────────────────────────────────────

  test "active AI agent with published config is available for work" do
    assert @lina.active_for_work?
  end

  test "draft AI agent is not available for work" do
    assert_not @scheduler.active_for_work?
  end

  test "paused AI agent is not available for work" do
    @lina.update!(operational_status: "paused")
    assert_not @lina.active_for_work?
  end

  test "AI agent with draft config is not available for work" do
    @lina.agent_configuration.update!(status: "draft")
    assert_not @lina.active_for_work?
  end

  test "human agent is not available for work (ai-only method)" do
    assert_not @human_agent.active_for_work?
  end

  test "inactive agent is not available for work" do
    @lina.update!(active: false)
    assert_not @lina.active_for_work?
  end

  # ── assignable? ──────────────────────────────────────────────────

  test "active human with active membership is assignable" do
    @human_agent.update!(operational_status: "active")
    assert @human_agent.assignable?
  end

  test "inactive human is not assignable" do
    @human_agent.update!(active: false)
    assert_not @human_agent.assignable?
  end

  test "human with inactive membership is not assignable" do
    @human_agent.membership.update!(active: false)
    assert_not @human_agent.assignable?
  end

  test "active AI with published config is assignable" do
    assert @lina.assignable?
  end

  test "draft AI is not assignable" do
    assert_not @scheduler.assignable?
  end

  test "paused AI is not assignable" do
    @lina.update!(operational_status: "paused")
    assert_not @lina.assignable?
  end

  # ── assignable scope ─────────────────────────────────────────────

  test "assignable scope includes eligible agents only" do
    assignable = Agent.assignable.where(account: @account)

    assert_includes assignable, @human_agent
    assert_includes assignable, @lina
    assert_not_includes assignable, @scheduler
  end

  test "assignable scope excludes paused AI agents" do
    @lina.update!(operational_status: "paused")

    assignable = Agent.assignable.where(account: @account)
    assert_not_includes assignable, @lina
  end

  test "assignable scope excludes agents with inactive memberships" do
    @human_agent.membership.update!(active: false)

    assignable = Agent.assignable.where(account: @account)
    assert_not_includes assignable, @human_agent
  end

  # ── operational? (unchanged) ─────────────────────────────────────

  test "operational? includes paused (backward compat for in-flight runs)" do
    @lina.update!(operational_status: "paused")
    assert @lina.operational?
  end

  test "operational? includes active" do
    assert @lina.operational?
  end

  test "operational? excludes draft" do
    assert_not @scheduler.operational?
  end

  test "operational? excludes archived" do
    @lina.update!(operational_status: "archived")
    assert_not @lina.operational?
  end
end