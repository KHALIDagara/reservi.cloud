require "test_helper"

class AgentOperationalStatusTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:alpha_alice_human)
  end

  test "defaults operational_status to draft" do
    assert_equal "draft", @agent.operational_status
  end

  test "validates operational_status inclusion" do
    @agent.operational_status = "bogus"
    assert_not @agent.valid?
    assert_includes @agent.errors[:operational_status].join, "not included"
  end

  test "allows valid operational_statuses" do
    %w[draft active paused archived].each do |value|
      @agent.operational_status = value
      assert @agent.valid?, "expected #{value} to be valid"
    end
  end

  test "operational? returns true for active and paused" do
    @agent.operational_status = "active"
    assert @agent.operational?

    @agent.operational_status = "paused"
    assert @agent.operational?

    @agent.operational_status = "draft"
    assert_not @agent.operational?

    @agent.operational_status = "archived"
    assert_not @agent.operational?
  end

  test "operational scope filters active and paused" do
    bob = agents(:alpha_bob_human)

    @agent.update!(operational_status: "active")
    bob.update!(operational_status: "paused")

    operational = Agent.operational
    assert_includes operational, @agent
    assert_includes operational, bob

    archived = agents(:alpha_dora_human)
    archived.update!(operational_status: "archived")
    assert_not_includes Agent.operational, archived
  end

  test "has_many agent_configurations" do
    config = AgentConfiguration.create!(
      account: @agent.account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )
    assert_includes @agent.agent_configurations, config
  end

  test "has_many ai_runs" do
    config = AgentConfiguration.create!(
      account: @agent.account, agent: @agent,
      version_number: 1, status: "published",
      guidance_config: {}, capability_config: {}
    )
    run = AiRun.create!(
      account: @agent.account,
      conversation: conversations(:alpha_active),
      agent: @agent,
      agent_configuration: config,
      status: "admitted",
      trigger: "inbound",
      admission_token: SecureRandom.uuid,
      conversation_revision: 0
    )
    assert_includes @agent.ai_runs, run
  end
end