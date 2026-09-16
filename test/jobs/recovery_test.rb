require "test_helper"

# Worker recovery and idempotency regression tests for T11 pilot readiness.
#
# Verifies that:
#   1. MessageDeliveryJob is idempotent — running it twice on a delivery that
#      was already processed (status != "pending") does not send again.
#   2. MessageDeliverySweepJob recovers stale pending deliveries by atomically
#      claiming and re-enqueuing them.
#   3. MessageDeliverySweepJob handles stuck "sending" deliveries.
#   4. Double-enqueue of the same operation_key is harmless — the database
#      unique index on operation_key prevents duplicate deliveries.

class RecoveryTest < ActiveJob::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)

    @channel = @account.channels.create!(
      name: "Recovery Test Channel",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16)
    )

    @message = @conversation.messages.create!(
      agent: agents(:alpha_alice_human),
      author_name: "Alice",
      content: "Recovery test message",
      direction: "outbound",
      delivery_status: "local"
    )
  end

  # ─────────────────────────────────────────────────────
  # 1. MessageDeliveryJob idempotency
  # ─────────────────────────────────────────────────────

  test "running MessageDeliveryJob twice does not produce second send" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "recovery_idempotent_1"
    )

    # First run: processes the pending delivery
    MessageDeliveryJob.perform_now(delivery.id)
    delivery.reload
    assert_equal "sent", delivery.status, "First run should complete the delivery"

    # Second run: must be idempotent — status is "sent", not "pending",
    # so the job should return immediately without changing anything.
    assert_no_changes -> { delivery.reload; delivery.status } do
      MessageDeliveryJob.perform_now(delivery.id)
    end
    assert_equal "sent", delivery.status
  end

  test "running MessageDeliveryJob on already-failed delivery is idempotent" do
    # Use the failure simulation pattern from DevAdapter
    fail_message = @conversation.messages.create!(
      agent: agents(:alpha_alice_human),
      author_name: "Alice",
      content: "SIMULATE_FAILURE recovery test",
      direction: "outbound",
      delivery_status: "local"
    )

    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: fail_message,
      status: "pending",
      operation_key: "recovery_fail_idempotent_1"
    )

    # First run fails
    MessageDeliveryJob.perform_now(delivery.id)
    delivery.reload
    assert_equal "failed", delivery.status

    # Second run: status is "failed", not "pending", so the job no-ops
    assert_no_changes -> { delivery.reload; delivery.status } do
      MessageDeliveryJob.perform_now(delivery.id)
    end
    assert_equal "failed", delivery.status
  end

  test "running MessageDeliveryJob on already-sending delivery is idempotent" do
    # A delivery stuck in "sending" state is not "pending", so the job
    # should no-op rather than re-send.
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "sending",
      operation_key: "recovery_sending_idempotent_1"
    )

    assert_no_changes -> { delivery.reload; delivery.status } do
      MessageDeliveryJob.perform_now(delivery.id)
    end
    assert_equal "sending", delivery.status
  end

  # ─────────────────────────────────────────────────────
  # 2. Stale pending recovery by sweep
  # ─────────────────────────────────────────────────────

  test "sweep re-enqueues stale pending delivery" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "recovery_stale_pending_1",
      created_at: 10.minutes.ago
    )

    # The sweep must atomically claim the delivery (pending → sending)
    # and then enqueue a MessageDeliveryJob for it.
    assert_enqueued_with(job: MessageDeliveryJob, args: [ delivery.id ]) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "sending", delivery.status,
      "Sweep should transition stale pending to sending"
  end

  test "sweep does not touch fresh pending delivery" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "recovery_fresh_pending_1",
      created_at: 30.seconds.ago
    )

    assert_no_enqueued_jobs(only: MessageDeliveryJob) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "pending", delivery.status,
      "Fresh pending deliveries should remain untouched"
  end

  # ─────────────────────────────────────────────────────
  # 3. Stuck sending recovery by sweep
  # ─────────────────────────────────────────────────────

  test "sweep marks stuck sending delivery as unknown" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "sending",
      operation_key: "recovery_stuck_sending_1",
      created_at: 10.minutes.ago,
      updated_at: 10.minutes.ago
    )

    MessageDeliverySweepJob.perform_now

    delivery.reload
    assert_equal "unknown", delivery.status,
      "Stuck sending deliveries should be marked as unknown"
    assert_match(/stuck in sending/i, delivery.error_message)
    assert_equal "unknown", @message.reload.delivery_status,
      "Message delivery_status should be synced to unknown"
  end

  test "sweep does not touch fresh sending delivery" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "sending",
      operation_key: "recovery_fresh_sending_1",
      created_at: 30.seconds.ago,
      updated_at: 30.seconds.ago
    )

    MessageDeliverySweepJob.perform_now

    delivery.reload
    assert_equal "sending", delivery.status,
      "Fresh sending deliveries should remain untouched"
  end

  # ─────────────────────────────────────────────────────
  # 4. Double-enqueue with same operation_key
  # ─────────────────────────────────────────────────────

  test "double enqueue with same operation_key does not create duplicates" do
    key = "recovery_duplicate_key_1"

    # First delivery created normally
    first = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: key
    )

    # Attempting to create a second delivery with the same operation_key
    # fails at the model validation level (uniqueness) which validates
    # before hitting the DB unique index.
    assert_raises(ActiveRecord::RecordInvalid) do
      @account.message_deliveries.create!(
        channel: @channel,
        message: @message,
        status: "pending",
        operation_key: key
      )
    end

    assert_equal 1, @account.message_deliveries.where(operation_key: key).count
  end

  test "sweep does not double-claim a delivery already claimed by the original job" do
    # This tests the atomic UPDATE ... WHERE status = 'pending' claim pattern.
    # After the sweep claims a pending delivery (pending → sending), the
    # original MessageDeliveryJob should no-op because it's no longer pending.
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "recovery_race_guard_1",
      created_at: 10.minutes.ago
    )

    # The sweep atomically claims it
    MessageDeliverySweepJob.perform_now
    delivery.reload
    assert_equal "sending", delivery.status

    # Now simulate the original (stale) job running — it should no-op
    # because delivery is no longer pending.
    assert_no_changes -> { delivery.reload; delivery.status } do
      MessageDeliveryJob.perform_now(delivery.id)
    end
    assert_equal "sending", delivery.status,
      "Original job must no-op when delivery is not pending"
  end

  test "sweep is idempotent — multiple sweeps do not produce duplicate enqueues" do
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "recovery_sweep_idempotent_1",
      created_at: 10.minutes.ago
    )

    # First sweep: claims pending → sending, enqueues job
    assert_enqueued_with(job: MessageDeliveryJob, args: [ delivery.id ]) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "sending", delivery.status

    # The delivery is now "sending" and not yet stale (updated_at was just set).
    # A second sweep should not find it in the stale pending query.
    assert_no_enqueued_jobs(only: MessageDeliveryJob) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "sending", delivery.status,
      "Second sweep should not re-touch an already-claimed delivery"
  end
end
