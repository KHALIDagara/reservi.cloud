require "test_helper"

class AiRunTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @agent = agents(:alpha_alice_human)
    @conversation = conversations(:alpha_active)
    @config = AgentConfiguration.create!(
      account: @account,
      agent: @agent,
      version_number: 1,
      status: "published",
      role: "Test role",
      guidance_config: {},
      capability_config: {},
      provider_type: "openai",
      model_identifier: "gpt-4",
      budget_limit_cents: 5000,
      max_concurrent_runs: 2
    )
  end

  test "creates valid ai_run" do
    run = AiRun.new(
      account: @account,
      conversation: @conversation,
      agent: @agent,
      agent_configuration: @config,
      status: "admitted",
      trigger: "inbound",
      admission_token: SecureRandom.uuid,
      conversation_revision: @conversation.revision
    )
    assert run.valid?
    assert run.save
    assert_equal "admitted", run.status
    assert run.active?
  end

  test "requires admission_token uniqueness" do
    token = SecureRandom.uuid
    AiRun.create!(
      account: @account,
      conversation: @conversation,
      agent: @agent,
      agent_configuration: @config,
      status: "admitted",
      trigger: "inbound",
      admission_token: token,
      conversation_revision: 0
    )

    duplicate = AiRun.new(
      account: @account,
      conversation: @conversation,
      agent: @agent,
      agent_configuration: @config,
      status: "admitted",
      trigger: "inbound",
      admission_token: token,
      conversation_revision: 0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:admission_token].join, "has already been taken"
  end

  test "validates status inclusion" do
    run = AiRun.new(status: "bogus")
    assert_not run.valid?
    assert_includes run.errors[:status].join, "not included"
  end

  test "active scope returns admitted and evaluating runs" do
    run1 = AiRun.create!(
      account: @account, conversation: @conversation,
      agent: @agent, agent_configuration: @config,
      status: "admitted", trigger: "inbound",
      admission_token: SecureRandom.uuid, conversation_revision: 0
    )
    run2 = AiRun.create!(
      account: @account, conversation: @conversation,
      agent: @agent, agent_configuration: @config,
      status: "evaluating", trigger: "inbound",
      admission_token: SecureRandom.uuid, conversation_revision: 0
    )
    run3 = AiRun.create!(
      account: @account, conversation: @conversation,
      agent: @agent, agent_configuration: @config,
      status: "completed", trigger: "inbound",
      admission_token: SecureRandom.uuid, conversation_revision: 0
    )

    active = AiRun.active
    assert_includes active, run1
    assert_includes active, run2
    assert_not_includes active, run3
  end

  test "for_conversation scope filters by conversation" do
    other_conv = conversations(:beta_active)
    other_agent = agents(:beta_alice_human)
    other_config = AgentConfiguration.create!(
      account: accounts(:beta), agent: other_agent,
      version_number: 1, status: "published",
      guidance_config: {}, capability_config: {}
    )

    run1 = AiRun.create!(
      account: @account, conversation: @conversation,
      agent: @agent, agent_configuration: @config,
      status: "admitted", trigger: "inbound",
      admission_token: SecureRandom.uuid, conversation_revision: 0
    )
    run2 = AiRun.create!(
      account: accounts(:beta), conversation: other_conv,
      agent: other_agent, agent_configuration: other_config,
      status: "admitted", trigger: "inbound",
      admission_token: SecureRandom.uuid, conversation_revision: 0
    )

    assert_includes AiRun.for_conversation(@conversation), run1
    assert_not_includes AiRun.for_conversation(@conversation), run2
  end

  # ── Transition rules ───────────────────────────

  test "admitted can transition to evaluating or failed or cancelled" do
    run = create_run("admitted")
    assert run.can_transition_to?("evaluating")
    assert run.can_transition_to?("failed")
    assert run.can_transition_to?("cancelled")
    assert_not run.can_transition_to?("completed")
    assert_not run.can_transition_to?("admitted")
  end

  test "evaluating can transition to completed or failed or cancelled" do
    run = create_run("evaluating")
    assert run.can_transition_to?("completed")
    assert run.can_transition_to?("failed")
    assert run.can_transition_to?("cancelled")
    assert_not run.can_transition_to?("admitted")
    assert_not run.can_transition_to?("evaluating")
  end

  test "terminal states have no valid transitions" do
    %w[completed failed cancelled].each do |terminal|
      run = create_run(terminal)
      AiRun::STATUSES.each do |target|
        assert_not run.can_transition_to?(target),
          "expected no transition from #{terminal} to #{target}"
      end
    end
  end

  test "transition_to! moves status and sets timestamp" do
    run = create_run("admitted")
    assert_nil run.started_at

    run.transition_to!("evaluating")
    run.reload
    assert_equal "evaluating", run.status
    assert_not_nil run.started_at
  end

  test "transition_to! to completed sets completed_at" do
    run = create_run("evaluating")
    run.transition_to!("completed")
    run.reload
    assert_equal "completed", run.status
    assert_not_nil run.completed_at
  end

  test "transition_to! to failed sets failed_at" do
    run = create_run("evaluating")
    run.transition_to!("failed")
    run.reload
    assert_equal "failed", run.status
    assert_not_nil run.failed_at
  end

  test "transition_to! raises ArgumentError for invalid transition" do
    run = create_run("completed")
    assert_raises(ArgumentError) { run.transition_to!("evaluating") }
  end

  test "transition_to! atomic guard prevents race" do
    run = create_run("admitted")

    # Simulate race: another process changed status between read and update
    AiRun.where(id: run.id).update_all(status: "evaluating")

    assert_raises(ActiveRecord::StaleObjectError) do
      run.transition_to!("evaluating") # run still thinks it's "admitted"
    end
  end

  test "admission_token is unique at DB level" do
    token = SecureRandom.uuid
    create_run("admitted", token: token)

    assert_raises(ActiveRecord::RecordNotUnique) do
      AiRun.connection.execute(<<~SQL)
        INSERT INTO ai_runs (
          account_id, conversation_id, agent_id, agent_configuration_id,
          status, trigger, admission_token, conversation_revision,
          created_at, updated_at
        ) VALUES (
          #{@account.id}, #{@conversation.id}, #{@agent.id}, #{@config.id},
          'admitted', 'inbound', '#{token}', 0,
          NOW(), NOW()
        )
      SQL
    end
  end

  private

  def create_run(status, token: nil)
    AiRun.create!(
      account: @account,
      conversation: @conversation,
      agent: @agent,
      agent_configuration: @config,
      status: status,
      trigger: "inbound",
      admission_token: token || SecureRandom.uuid,
      conversation_revision: 0
    )
  end
end