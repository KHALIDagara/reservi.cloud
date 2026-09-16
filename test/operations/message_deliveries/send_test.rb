require "test_helper"

class MessageDeliveries::SendTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @agent = agents(:alpha_alice_human)
    @channel = @account.channels.create!(
      name: "Test Channel",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16)
    )
  end

  test "creates message and delivery and enqueues job" do
    assert_difference({ -> { @conversation.messages.count } => 1, -> { @account.message_deliveries.count } => 1 }) do
      assert_enqueued_with(job: MessageDeliveryJob) do
        MessageDeliveries::Send.call(
          conversation: @conversation,
          channel: @channel,
          agent: @agent,
          content: "Hello from Reservi!",
          operation_key: "op_#{SecureRandom.hex(8)}"
        )
      end
    end

    delivery = @account.message_deliveries.last
    assert_equal "pending", delivery.status
    assert_equal @channel.id, delivery.channel_id
    assert_equal @conversation.id, delivery.message.conversation_id
  end

  test "is idempotent — same operation_key returns existing delivery" do
    key = "idempotent_test"

    first = MessageDeliveries::Send.call(
      conversation: @conversation,
      channel: @channel,
      agent: @agent,
      content: "Hello!",
      operation_key: key
    )

    assert_no_difference [ -> { @conversation.messages.count }, -> { @account.message_deliveries.count } ] do
      second = MessageDeliveries::Send.call(
        conversation: @conversation,
        channel: @channel,
        agent: @agent,
        content: "Hello!",
        operation_key: key
      )
      assert_equal first.id, second.id
    end
  end

  test "rejects inactive channel" do
    @channel.update!(active: false)

    assert_raises(Reservi::Errors::OperationError, match: /not active/) do
      MessageDeliveries::Send.call(
        conversation: @conversation,
        channel: @channel,
        agent: @agent,
        content: "Hello!",
        operation_key: "op_#{SecureRandom.hex(8)}"
      )
    end
  end
end
