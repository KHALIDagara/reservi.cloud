require "test_helper"

class AgentKnowledgeGrantTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @agent   = agents(:alpha_alice_human)
    @source  = KnowledgeSource.create!(account: @account, title: "Grant Test Source", kind: "qa")
  end

  test "creates grant linking agent to source" do
    grant = AgentKnowledgeGrant.new(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )
    assert grant.valid?
    grant.save!
    assert_includes @agent.knowledge_grants, grant
    assert_includes @source.grants, grant
  end

  test "uniqueness per agent + source" do
    AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )

    duplicate = AgentKnowledgeGrant.new(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:agent_id].join, "taken"
  end

  test "allows same agent with different source" do
    AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )

    source2 = KnowledgeSource.create!(account: @account, title: "Other Source", kind: "document")
    grant2  = AgentKnowledgeGrant.new(
      account:           @account,
      agent:             @agent,
      knowledge_source:  source2
    )
    assert grant2.valid?
  end

  test "allows different agent with same source" do
    AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )

    agent2 = agents(:alpha_bob_human)
    grant2 = AgentKnowledgeGrant.new(
      account:           @account,
      agent:             agent2,
      knowledge_source:  @source
    )
    assert grant2.valid?
    grant2.save!
    assert_includes @source.agents.reload, @agent
    assert_includes @source.agents, agent2
  end

  test "scope :active works" do
    active_grant = AgentKnowledgeGrant.create!(
      account: @account, agent: @agent, knowledge_source: @source,
      active: true
    )

    source2 = KnowledgeSource.create!(account: @account, title: "Inactive Grant Source", kind: "scenario")
    inactive_grant = AgentKnowledgeGrant.create!(
      account: @account, agent: @agent, knowledge_source: source2,
      active: false
    )

    active_grants = AgentKnowledgeGrant.active
    assert_includes     active_grants, active_grant
    assert_not_includes active_grants, inactive_grant
  end

  test "defaults active to true" do
    grant = AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @source
    )
    assert grant.active
  end
end
