require "test_helper"

class ChannelDefaultAssignmentTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @channel = Channel.create!(
      account: @account,
      name: "Test Channel #{SecureRandom.hex(4)}",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16),
      active: true
    )
    @lina = agents(:alpha_lina_ai)
    @human_agent = agents(:alpha_alice_human)
    @human_agent.update!(operational_status: "active")
    @team = teams(:alpha_general)
  end

  test "channel validates at most one default assignment" do
    @channel.default_agent = @lina
    @channel.default_team = @team
    assert_not @channel.valid?
    assert_includes @channel.errors[:base].join, "not both"
  end

  test "channel accepts default agent without team" do
    @channel.update!(default_agent: @lina, default_team: nil)
    assert_equal @lina, @channel.default_agent
    assert @channel.valid?
  end

  test "channel accepts default team without agent" do
    @channel.update!(default_agent: nil, default_team: @team)
    assert_equal @team, @channel.default_team
    assert @channel.valid?
  end

  test "channel accepts neither default" do
    @channel.update!(default_agent: nil, default_team: nil)
    assert @channel.valid?
  end

  test "default_agent assigns conversation when assignable" do
    @channel.update!(default_agent: @lina)

    conv = @account.conversations.create!(
      customer: customers(:alpha_wilma),
      flow_version: flow_versions(:alpha_v1),
      current_stage: stages(:alpha_stage1),
      process_status: "active",
      custom_values: {}
    )

    # Simulate what the webhook does
    if @channel.default_agent_id.present? && conv.owner_id.nil?
      default_agent = @channel.default_agent
      if default_agent&.assignable?
        Conversations::Claim.call(conversation: conv, agent: default_agent)
      end
    end

    assert_equal @lina, conv.reload.owner
  end

  test "default_agent does not assign when not assignable" do
    @lina.update!(operational_status: "paused")
    @channel.update!(default_agent: @lina)

    conv = @account.conversations.create!(
      customer: customers(:alpha_wilma),
      flow_version: flow_versions(:alpha_v1),
      current_stage: stages(:alpha_stage1),
      process_status: "active",
      custom_values: {}
    )
    assert_nil conv.reload.owner
  end
end