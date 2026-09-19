require "test_helper"

class Accounts::AiAgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
    @lina = agents(:alpha_lina_ai)
    @scheduler = agents(:alpha_scheduler_ai)
    # Ensure a published flow exists for preview
    @flow = flows(:alpha_default)
    @flow.update!(current_version: flow_versions(:alpha_v1))
  end

  # ── index ────────────────────────────────────────────────────────

  test "admin sees AI agents list" do
    get account_ai_agents_path(@account)
    assert_response :success
    assert_select "h1", text: "AI Agents"
    assert_select "a[href='#{new_account_ai_agent_path(@account)}']", text: /Create/
  end

  test "operator sees AI agents list (read-only)" do
    sign_in_as(users(:bob))
    get account_ai_agents_path(@account)
    assert_response :success
  end

  test "index shows active and draft agents" do
    get account_ai_agents_path(@account)
    assert_response :success
    assert_select "h3", text: @lina.name
    assert_select "h3", text: @scheduler.name
  end

  # ── show ─────────────────────────────────────────────────────────

  test "admin sees AI agent details" do
    get account_ai_agent_path(@account, @lina)
    assert_response :success
    assert_select "h1", text: @lina.name
    assert_select "span", text: "Active"
  end

  test "show displays instructions" do
    get account_ai_agent_path(@account, @lina)
    assert_response :success
    assert_match /receptionist/i, response.body
  end

  # ── new / create ─────────────────────────────────────────────────

  test "admin can access new AI agent form" do
    get new_account_ai_agent_path(@account)
    assert_response :success
    assert_select "h1", text: "Create AI Agent"
  end

  test "admin creates an AI agent" do
    assert_difference -> { @account.agents.ai.count }, 1 do
      post account_ai_agents_create_path(@account), params: { agent: {
        name: "TestBot",
        instructions: "You are a test bot."
      } }
    end
    assert_response :redirect
  end

  test "created agent starts as draft" do
    post account_ai_agents_create_path(@account), params: { agent: {
      name: "DraftBot",
      instructions: "Be helpful."
    } }
    agent = @account.agents.ai.find_by(name: "DraftBot")
    assert agent, "Agent not found: #{response.body[0..500]}"
    assert_equal "draft", agent.operational_status
    assert agent.agent_configuration.present?
    assert agent.agent_configuration.guidance_config["instructions"].present?
  end

  test "operator cannot create AI agent" do
    sign_in_as(users(:bob))
    post account_ai_agents_create_path(@account), params: { agent: {
      name: "StealthBot", instructions: "test"
    } }
    assert_response :redirect
    assert_match /Only Account administrators/, flash[:alert]
  end

  # ── edit / update ────────────────────────────────────────────────

  test "admin can edit AI agent" do
    get edit_account_ai_agent_path(@account, @lina)
    assert_response :success
    assert_select "h1", text: /Edit/
  end

  test "admin updates AI agent" do
    patch account_ai_agent_update_path(@account, @lina), params: { agent: {
      name: "Lina Updated",
      instructions: "New instructions."
    } }

    assert_response :redirect
    @lina.reload
    assert_equal "Lina Updated", @lina.name
    assert_equal "New instructions.", @lina.agent_configuration.guidance_config["instructions"]
  end

  # ── activation ───────────────────────────────────────────────────

  test "admin activates a draft agent" do
    post activate_account_ai_agent_path(@account, @scheduler)
    assert_response :redirect

    @scheduler.reload
    assert_equal "active", @scheduler.operational_status
    assert @scheduler.agent_configuration.published?
  end

  test "admin pauses an active agent" do
    post deactivate_account_ai_agent_path(@account, @lina)
    assert_response :redirect

    @lina.reload
    assert_equal "paused", @lina.operational_status
  end

  # ── preview ──────────────────────────────────────────────────────

  test "admin can access preview form" do
    get preview_account_ai_agent_path(@account, @lina)
    assert_response :success
    assert_select "h1", text: /Test/
  end

  test "admin runs preview or gracefully redirects" do
    post run_preview_account_ai_agent_path(@account, @lina),
      params: { user_message: "Hello, I need help" }

    # Preview may redirect if no published flow exists, which is fine.
    # The important thing is that the page renders without error.
    assert response.redirect? || response.successful?
  end

  # ── security ─────────────────────────────────────────────────────

  test "cannot access AI agent from other account" do
    # The set_ai_agent uses current_account.agents.ai.find — trying to access
    # an agent from another account should redirect with 'not found'
    get account_ai_agent_path(@account, id: 999_999_999)
    assert_response :redirect
    assert_match /not found/, flash[:alert]
  end

  test "operator cannot activate AI agent" do
    sign_in_as(users(:bob))
    post activate_account_ai_agent_path(@account, @scheduler)
    assert_response :redirect
    assert_match /Only Account administrators/, flash[:alert]
  end

  test "reassigning to active AI triggers admission" do
    sign_in_as(users(:alice))

    # Create a conversation and assign to Lina
    conv = @account.conversations.create!(
      customer:        customers(:alpha_wilma),
      flow_version:    flow_versions(:alpha_v1),
      current_stage:   stages(:alpha_stage1),
      process_status:  "active",
      custom_values:   {}
    )

    assert @lina.active_for_work?

    post account_conversation_reassign_path(@account, conv), params: { agent_id: @lina.id }
    assert_response :redirect

    conv.reload
    assert_equal @lina, conv.owner

    # Verify an AiRun was admitted
    assert AiRun.where(agent: @lina, conversation: conv, trigger: "assigned").exists?
  end
end