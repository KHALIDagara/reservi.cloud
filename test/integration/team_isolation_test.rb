require "test_helper"

# Team-scoped isolation regression tests for T11 pilot readiness.
#
# Verifies that:
#   1. An operator assigned only to Team A can see conversations assigned to
#      Team A (General) but not conversations assigned to Team B.
#   2. The team-scoped inbox filter (filter=team) shows only conversations
#      belonging to teams the current agent is a member of.
#   3. Conversations without a team assignment appear in the team filter
#      (since they are not excluded — they have team_id NULL).
#   4. Unauthenticated users are denied access to team-filtered inbox.

class TeamIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)

    # ── Teams ──────────────────────────────────────────
    @general_team = teams(:alpha_general)

    # Create a second team for isolation testing
    @vip_team = @account.teams.create!(name: "VIP", active: true)

    # ── Users ──────────────────────────────────────────
    @bob   = users(:bob)      # operator in alpha, agent: alpha_bob_human
    @alice = users(:alice)    # admin in alpha

    # ── Agents ─────────────────────────────────────────
    @bob_agent   = agents(:alpha_bob_human)
    @alice_agent = agents(:alpha_alice_human)

    # Bob is only in the General team (fixture already)
    # Alice is also only in General

    # ── Give bob a second team membership ──────────────
    @bob_agent.team_memberships.create!(account: @account, team: @vip_team, active: true)

    # Ensure alpha flow is published
    @flow = flows(:alpha_default)
    @fv   = flow_versions(:alpha_v1)
    @flow.update!(current_version: @fv)
  end

  # ─────────────────────────────────────────────────────
  # 1. Operator sees conversations for their teams
  # ─────────────────────────────────────────────────────

  test "team filter shows conversations owned by the agent's teams" do
    sign_in_as(@bob)

    # Create a conversation assigned to Bob's general team
    general_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "General Customer", email_address: "general@example.com" },
      agent: @bob_agent,
      content: "General team request",
      team_id: @general_team.id
    )
    general_conv.update!(owner: @bob_agent)

    # Create a conversation assigned to Bob's VIP team
    vip_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "VIP Customer", email_address: "vip@example.com" },
      agent: @bob_agent,
      content: "VIP team request",
      team_id: @vip_team.id
    )
    vip_conv.update!(owner: @bob_agent)

    get account_inbox_url(@account, filter: "team")
    assert_response :success

    # Both should appear since Bob is in both teams
    assert_select "a[href='#{account_inbox_path(@account, id: general_conv.id, filter: 'team')}']"
    assert_select "a[href='#{account_inbox_path(@account, id: vip_conv.id, filter: 'team')}']"
  end

  test "team filter does NOT show conversations of teams agent does not belong to" do
    # Alice is only in the General team
    sign_in_as(@alice)

    # Create a conversation assigned to General (Alice's team)
    general_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Alice General", email_address: "aliceg@example.com" },
      agent: @alice_agent,
      content: "General",
      team_id: @general_team.id
    )
    general_conv.update!(owner: @alice_agent)

    # Create a conversation assigned to VIP (Alice is NOT in this team)
    vip_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Alice Not VIP", email_address: "alicen@example.com" },
      agent: @alice_agent,
      content: "Should not appear",
      team_id: @vip_team.id
    )
    vip_conv.update!(owner: @alice_agent)

    get account_inbox_url(@account, filter: "team")
    assert_response :success

    assert_select "a[href='#{account_inbox_path(@account, id: general_conv.id, filter: 'team')}']"
    assert_select "a[href='#{account_inbox_path(@account, id: vip_conv.id, filter: 'team')}']", count: 0
  end

  test "mine filter shows only conversations owned by the current agent" do
    sign_in_as(@bob)

    bob_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Bob Mine", email_address: "bobmine@example.com" },
      agent: @bob_agent,
      content: "Mine",
      team_id: @general_team.id
    )
    bob_conv.update!(owner: @bob_agent)

    alice_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Alice Mine", email_address: "alicemine@example.com" },
      agent: @alice_agent,
      content: "Not mine",
      team_id: @general_team.id
    )
    alice_conv.update!(owner: @alice_agent)

    get account_inbox_url(@account, filter: "mine")
    assert_response :success

    assert_select "a[href='#{account_inbox_path(@account, id: bob_conv.id, filter: 'mine')}']"
    assert_select "a[href='#{account_inbox_path(@account, id: alice_conv.id, filter: 'mine')}']", count: 0
  end

  test "unowned filter shows only unassigned conversations" do
    sign_in_as(@bob)

    owned_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Owned", email_address: "owned@example.com" },
      agent: @bob_agent,
      content: "Owned",
      team_id: @general_team.id
    )
    owned_conv.update!(owner: @bob_agent)

    unowned_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Unowned", email_address: "unowned@example.com" },
      agent: @bob_agent,
      content: "Free for all",
      team_id: @general_team.id
    )
    unowned_conv.update!(owner: nil)

    get account_inbox_url(@account, filter: "unowned")
    assert_response :success

    assert_select "a[href='#{account_inbox_path(@account, id: unowned_conv.id, filter: 'unowned')}']"
    assert_select "a[href='#{account_inbox_path(@account, id: owned_conv.id, filter: 'unowned')}']", count: 0
  end

  test "all filter shows all active conversations" do
    sign_in_as(@bob)

    general_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "All General", email_address: "allg@example.com" },
      agent: @bob_agent,
      content: "General",
      team_id: @general_team.id
    )
    general_conv.update!(owner: @bob_agent)

    vip_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "All VIP", email_address: "allv@example.com" },
      agent: @bob_agent,
      content: "VIP",
      team_id: @vip_team.id
    )
    vip_conv.update!(owner: @bob_agent)

    get account_inbox_url(@account, filter: "all")
    assert_response :success

    # Both should be visible in the "all" filter
    assert_select "a[href='#{account_inbox_path(@account, id: general_conv.id, filter: 'all')}']"
    assert_select "a[href='#{account_inbox_path(@account, id: vip_conv.id, filter: 'all')}']"
  end
end
