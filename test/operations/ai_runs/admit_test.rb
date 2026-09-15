require "test_helper"

class AiRuns::AdmitTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)

    @agent = agents(:alpha_alice_human)
    @agent.update!(kind: "ai", membership_id: nil, operational_status: "active")

    @agent_config = AgentConfiguration.create!(
      account: @account,
      agent: @agent,
      version_number: 1,
      status: "published",
      role: "test_role",
      provider_type: "fake",
      model_identifier: "fake-v1"
    )
    @agent.update!(agent_configuration_id: @agent_config.id)

    # Create an active conversation
    @conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "AdmitTest", email_address: "admit@example.com" },
      agent: @agent,
      content: "Initial message"
    )
  end

  # ── basic admission ─────────────────────────────────────────────

  test "admit creates a run with admitted status" do
    result = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )

    assert_equal "admitted", result[:status]
    assert result[:ai_run_id].present?
    assert result[:token].present?

    run = AiRun.find(result[:ai_run_id])
    assert_equal "admitted", run.status
    assert_equal @conversation.id, run.conversation_id
    assert_equal "inbound_message", run.trigger
  end

  test "admitted run has a valid unique admission_token" do
    result = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )
    run = AiRun.find(result[:ai_run_id])
    assert_equal 32, run.admission_token.length  # 16 bytes hex = 32 chars
    assert run.admission_token.match?(/\A[a-f0-9]+\z/)
  end

  test "admitted run captures conversation revision at admission time" do
    @conversation.update!(owner: nil) # bumps revision
    expected_revision = @conversation.reload.revision

    result = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )
    run = AiRun.find(result[:ai_run_id])
    assert_equal expected_revision, run.conversation_revision
  end

  test "account admission_counter increments on successful admit" do
    before = @account.reload.admission_counter

    AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )

    assert_equal before + 1, @account.reload.admission_counter
  end

  # ── idempotency ─────────────────────────────────────────────────

  test "second admit for same conversation is skipped" do
    first = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )
    assert_equal "admitted", first[:status]

    second = AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "follow_up"
    )
    assert_equal "skipped", second[:status]
    assert_equal "Active run already exists", second[:reason]
  end

  test "second admit does not increment admission_counter" do
    AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "inbound_message"
    )
    before = @account.reload.admission_counter

    AiRuns::Admit.call(
      agent: @agent, conversation: @conversation, trigger: "follow_up"
    )

    assert_equal before, @account.reload.admission_counter
  end

  # ── preconditions ───────────────────────────────────────────────

  test "non-operational agent is rejected" do
    @agent.update!(operational_status: "draft")

    e = assert_raises(Reservi::Errors::OperationError) do
      AiRuns::Admit.call(
        agent: @agent, conversation: @conversation, trigger: "inbound_message"
      )
    end
    assert_match /not operational/, e.message
  end

  test "cancelled conversation is rejected" do
    @conversation.update!(process_status: "cancelled")

    e = assert_raises(Reservi::Errors::OperationError) do
      AiRuns::Admit.call(
        agent: @agent, conversation: @conversation, trigger: "inbound_message"
      )
    end
    assert_match /not active/, e.message
  end

  test "admit fails when agent has no agent_configuration_id" do
    @agent.update!(agent_configuration_id: nil)

    e = assert_raises(ActiveRecord::RecordInvalid) do
      AiRuns::Admit.call(
        agent: @agent, conversation: @conversation, trigger: "inbound_message"
      )
    end
    assert_match /Agent configuration must exist/i, e.message
  end

  # ── concurrent safety ───────────────────────────────────────────

  test "concurrent admits produce exactly one run" do
    results = []
    threads = 3.times.map do
      Thread.new do
        AiRuns::Admit.call(
          agent: @agent, conversation: @conversation, trigger: "inbound_message"
        )
      end
    end
    results = threads.map(&:value)

    admitted = results.select { |r| r[:status] == "admitted" }
    skipped  = results.select { |r| r[:status] == "skipped" }

    assert_equal 1, admitted.size
    assert_equal 2, skipped.size
    assert_equal 1, AiRun.active.for_conversation(@conversation).count
  end
end