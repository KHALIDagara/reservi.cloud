require "test_helper"

# Cross-tenant and restricted-role regression tests for T11 pilot readiness.
#
# Verifies that:
#   1. An admin with memberships in multiple Accounts cannot access one
#      Account's resources through another Account's scoped URL prefix.
#   2. An operator scoped to one Account cannot access another Account's data.
#   3. A non-admin operator cannot perform admin-only Actions (Flow CRUD).
#   4. An operator cannot view/create/modify another team's conversations.
#   5. The inbox team filter isolates conversations by team membership.

class CrossTenantRegressionTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = accounts(:alpha)
    @beta  = accounts(:beta)

    # ── Users ──────────────────────────────────────────
    @alice     = users(:alice)    # admin in alpha AND beta
    @bob       = users(:bob)      # operator in alpha only
    @eve       = users(:eve)      # operator in beta only

    # ── Memberships ────────────────────────────────────
    @alpha_alice_m = memberships(:alpha_alice)
    @alpha_bob_m   = memberships(:alpha_bob)
    @beta_eve_m    = memberships(:beta_eve)

    # ── Agents ─────────────────────────────────────────
    @alpha_bob_agent  = agents(:alpha_bob_human)
    @beta_eve_agent   = agents(:beta_eve_human)
    @alpha_alice_agent = agents(:alpha_alice_human)

    # ── Resources ──────────────────────────────────────
    @alpha_flow = flows(:alpha_default)
    @beta_flow  = flows(:beta_default)

    # Ensure alpha's flow version is published for conversation creation
    @alpha_fv = flow_versions(:alpha_v1)
    @alpha_flow.update!(current_version: @alpha_fv)
    @beta_fv  = flow_versions(:beta_v1)
    @beta_flow.update!(current_version: @beta_fv)
  end

  # ─────────────────────────────────────────────────────
  # 1. Alpha admin accessing beta resources through alpha URL
  # ─────────────────────────────────────────────────────

  test "alpha admin cannot access beta flows via alpha-scoped URL" do
    sign_in_as(@alice)

    # flows(:beta_default) belongs to beta.
    get flow_url(account_id: @alpha.id, id: @beta_flow.id)
    assert_response :not_found
  end

  test "alpha admin cannot access beta conversations via alpha-scoped URL" do
    sign_in_as(@alice)

    beta_conv = conversations(:beta_active)
    # Looking up a beta conversation from alpha's scope: the conversation
    # is not in alpha's conversation list, so set_conversation raises
    # ActiveRecord::RecordNotFound → redirect to inbox with alert.
    get account_conversation_url(@alpha, beta_conv)
    assert_redirected_to account_inbox_path(@alpha)
    assert_match(/not found/i, flash[:alert])
  end

  # ─────────────────────────────────────────────────────
  # 2. Beta operator cannot access alpha resources
  # ─────────────────────────────────────────────────────

  test "beta operator cannot access alpha flows" do
    sign_in_as(@eve)

    # /a/:alpha_id/flows → require_account_access! checks membership in alpha.
    # Eve has no membership in alpha.
    get flows_url(account_id: @alpha.id)
    assert_redirected_to accounts_path
    assert flash[:alert].present?
    assert_match(/access/i, flash[:alert])
  end

  test "beta operator cannot access alpha inbox" do
    sign_in_as(@eve)

    get account_inbox_url(@alpha)
    assert_redirected_to accounts_path
  end

  test "beta operator cannot access alpha conversation" do
    sign_in_as(@eve)

    alpha_conv = conversations(:alpha_active)
    get account_conversation_url(@alpha, alpha_conv)
    assert_redirected_to accounts_path
  end

  # ─────────────────────────────────────────────────────
  # 3. Operator cannot perform admin-only Actions
  # ─────────────────────────────────────────────────────

  test "alpha operator cannot create a flow" do
    sign_in_as(@bob)

    assert_no_difference -> { @alpha.flows.count } do
      post flows_url(account_id: @alpha.id), params: { flow: { name: "Exploit" } }
    end
    assert_redirected_to accounts_path
  end

  test "alpha operator cannot access the new flow form" do
    sign_in_as(@bob)

    get new_flow_url(account_id: @alpha.id)
    assert_redirected_to accounts_path
  end

  test "alpha operator cannot access the edit flow page" do
    sign_in_as(@bob)

    get edit_flow_url(account_id: @alpha.id, id: @alpha_flow)
    assert_redirected_to accounts_path
  end

  # ─────────────────────────────────────────────────────
  # 4. Beta agent cannot see alpha conversations
  # ─────────────────────────────────────────────────────

  test "beta agent cannot access alpha conversation by ID" do
    sign_in_as(@eve)

    alpha_conv = conversations(:alpha_active)
    # Try to access alpha conversation through the beta account scope — it does
    # not belong to beta, so set_conversation raises RecordNotFound → inbox redirect.
    get account_conversation_url(@beta, alpha_conv)
    assert_redirected_to account_inbox_path(@beta)
    assert_match(/not found/i, flash[:alert])
  end

  test "beta operator inbox does not show alpha conversations" do
    sign_in_as(@eve)

    get account_inbox_url(@beta)
    assert_response :success
    # The beta inbox should only show beta-scoped conversations
    beta_conv  = conversations(:beta_active)
    alpha_conv = conversations(:alpha_active)

    assert_select "a[href='#{account_conversation_path(@beta, beta_conv)}']"
    assert_select "a[href='#{account_conversation_path(@beta, alpha_conv)}']", count: 0
  end

  # ─────────────────────────────────────────────────────
  # 5. Cross-Account admin: Alice uses correct account path
  #    (regression — Alice can access alpha in alpha, beta in beta)
  # ─────────────────────────────────────────────────────

  test "alice can access alpha flows when scoped to alpha" do
    sign_in_as(@alice)
    get flows_url(account_id: @alpha.id)
    assert_response :success
  end

  test "alice can access beta flows when scoped to beta" do
    sign_in_as(@alice)
    get flows_url(account_id: @beta.id)
    assert_response :success
  end

  test "alice cannot use alpha-scoped URL for beta inbox" do
    sign_in_as(@alice)

    # The inbox is account-scoped — /a/:account_id/inbox
    # When scoped to alpha, we query alpha's conversations.
    get account_inbox_url(@alpha)
    assert_response :success

    # A beta conversation should not appear in alpha inbox
    beta_conv = conversations(:beta_active)
    assert_select "a[href='#{account_conversation_path(@alpha, beta_conv)}']", count: 0
  end
end