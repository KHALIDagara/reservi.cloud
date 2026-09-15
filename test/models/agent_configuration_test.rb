require "test_helper"

class AgentConfigurationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @agent = agents(:alpha_alice_human)
  end

  test "creates valid configuration" do
    config = AgentConfiguration.new(
      account: @account,
      agent: @agent,
      version_number: 1,
      status: "draft",
      role: "Test role",
      guidance_config: { tone: "professional" },
      capability_config: { allowed_actions: ["send_message"] },
      provider_type: "openai",
      model_identifier: "gpt-4",
      budget_limit_cents: 5000,
      max_concurrent_runs: 2
    )
    assert config.valid?
    config.save!
    assert_equal "draft", config.status
    assert_not config.published?
  end

  test "published? returns true only for published status" do
    draft = AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )
    published = AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 2, status: "published",
      guidance_config: {}, capability_config: {}
    )

    assert_not draft.published?
    assert published.published?
  end

  test "version_number uniqueness per agent" do
    AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )

    duplicate = AgentConfiguration.new(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:version_number].join, "must be unique per agent"
  end

  test "different agents can share version_numbers" do
    other_agent = agents(:alpha_bob_human)
    AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )

    config = AgentConfiguration.new(
      account: @account, agent: other_agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )
    assert config.valid?
  end

  test "validates status inclusion" do
    config = AgentConfiguration.new(
      account: @account, agent: @agent,
      version_number: 1, status: "bogus",
      guidance_config: {}, capability_config: {}
    )
    assert_not config.valid?
    assert_includes config.errors[:status].join, "not included"
  end

  test "scopes filter correctly" do
    draft = AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )
    published = AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 2, status: "published",
      guidance_config: {}, capability_config: {}
    )

    assert_includes AgentConfiguration.draft, draft
    assert_not_includes AgentConfiguration.draft, published
    assert_includes AgentConfiguration.published, published
    assert_not_includes AgentConfiguration.published, draft
  end

  test "version_number uniqueness enforced at DB level" do
    AgentConfiguration.create!(
      account: @account, agent: @agent,
      version_number: 1, status: "draft",
      guidance_config: {}, capability_config: {}
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      AgentConfiguration.connection.execute(<<~SQL)
        INSERT INTO agent_configurations (
          account_id, agent_id, version_number, status,
          guidance_config, capability_config,
          created_at, updated_at
        ) VALUES (
          #{@account.id}, #{@agent.id}, 1, 'draft',
          '{}', '{}',
          NOW(), NOW()
        )
      SQL
    end
  end
end