require "test_helper"

# Acceptance T01 #4: Account-scoped composite foreign keys must reject
# mismatched associations even through direct database writes (INV-001/080).
class TenantIntegrityTest < ActiveSupport::TestCase
  setup do
    @alpha = accounts(:alpha)
    @beta = accounts(:beta)
    @alpha_team = teams(:alpha_general)
    @beta_team = teams(:beta_general)
    @alpha_agent = agents(:alpha_alice_human)
    @beta_agent = agents(:beta_carol_human)
    @alpha_membership = memberships(:alpha_alice)
  end

  def insert_team_membership(account_id:, team_id:, agent_id:)
    TeamMembership.connection.execute(<<~SQL)
      INSERT INTO team_memberships (account_id, team_id, agent_id, active, created_at, updated_at)
      VALUES (#{account_id}, #{team_id}, #{agent_id}, true, NOW(), NOW())
    SQL
  end

  test "team from another Account cannot be bound to this Account's agent" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      insert_team_membership(account_id: @alpha.id, team_id: @beta_team.id, agent_id: @alpha_agent.id)
    end
  end

  test "agent from another Account cannot be bound to this Account's team" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      insert_team_membership(account_id: @alpha.id, team_id: @alpha_team.id, agent_id: @beta_agent.id)
    end
  end

  test "Agent cannot reference a Membership from another Account" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Agent.connection.execute(<<~SQL)
        INSERT INTO agents (account_id, kind, membership_id, name, active, capabilities, created_at, updated_at)
        VALUES (#{@alpha.id}, 'human', #{memberships(:beta_carol).id}, 'Cross', true, '{}', NOW(), NOW())
      SQL
    end
  end

  test "database check constraint forbids an AI Agent with a Membership" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Agent.connection.execute(<<~SQL)
        INSERT INTO agents (account_id, kind, membership_id, name, active, capabilities, created_at, updated_at)
        VALUES (#{@alpha.id}, 'ai', #{@alpha_membership.id}, 'Lina', true, '{}', NOW(), NOW())
      SQL
    end
  end

  test "database check constraint forbids a human Agent without a Membership" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Agent.connection.execute(<<~SQL)
        INSERT INTO agents (account_id, kind, membership_id, name, active, capabilities, created_at, updated_at)
        VALUES (#{@alpha.id}, 'human', NULL, 'Ghost', true, '{}', NOW(), NOW())
      SQL
    end
  end

  test "database check constraint rejects an unknown membership role" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Membership.connection.execute(<<~SQL)
        INSERT INTO memberships (account_id, user_id, role, active, created_at, updated_at)
        VALUES (#{@alpha.id}, #{users(:dora).id}, 'owner', true, NOW(), NOW())
      SQL
    end
  end
end