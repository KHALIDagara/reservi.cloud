require "test_helper"

class MessageDeliverySweepJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:alpha)
    @channel = @account.channels.create!(
      name: "Sweep Test",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16)
    )
    @conversation = conversations(:alpha_active)
    @message = @conversation.messages.create!(
      author_name: "Test", content: "Sweep test",
      direction: "outbound", delivery_status: "local"
    )
  end

  test "re-enqueues stale pending deliveries" do
    delivery = @account.message_deliveries.create!(
      channel: @channel, message: @message,
      status: "pending", operation_key: "stale_pending_1",
      created_at: 10.minutes.ago
    )

    assert_enqueued_with(job: MessageDeliveryJob) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "sending", delivery.status
  end

  test "marks stuck sending deliveries as unknown" do
    delivery = @account.message_deliveries.create!(
      channel: @channel, message: @message,
      status: "sending", operation_key: "stuck_sending_1",
      created_at: 10.minutes.ago, updated_at: 10.minutes.ago
    )

    MessageDeliverySweepJob.perform_now

    delivery.reload
    assert_equal "unknown", delivery.status
    assert_match /stuck in sending/, delivery.error_message
    assert_equal "unknown", @message.reload.delivery_status
  end

  test "does not touch recent pending deliveries" do
    delivery = @account.message_deliveries.create!(
      channel: @channel, message: @message,
      status: "pending", operation_key: "fresh_pending",
      created_at: 1.minute.ago
    )

    assert_no_enqueued_jobs(only: MessageDeliveryJob) do
      MessageDeliverySweepJob.perform_now
    end

    delivery.reload
    assert_equal "pending", delivery.status
  end

  test "does not touch recent sending deliveries" do
    delivery = @account.message_deliveries.create!(
      channel: @channel, message: @message,
      status: "sending", operation_key: "fresh_sending",
      created_at: 1.minute.ago, updated_at: 1.minute.ago
    )

    MessageDeliverySweepJob.perform_now

    delivery.reload
    assert_equal "sending", delivery.status
  end
end
