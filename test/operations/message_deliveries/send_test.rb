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

  test "creates delivery and enqueues job" do
    message = @conversation.messages.create!(
      agent: @agent,
      author_name: @agent.name,
      content: "Hello from Reservi!",
      direction: "outbound",
      delivery_status: "local"
    )

    assert_difference -> { @conversation.messages.count } => 0,
                      -> { @account.message_deliveries.count } => 1 do
      assert_enqueued_with(job: MessageDeliveryJob) do
        MessageDeliveries::Send.call(
          conversation: @conversation,
          channel: @channel,
          agent: @agent,
          message: message,
          operation_key: "op_#{SecureRandom.hex(8)}"
        )
      end
    end

    delivery = @account.message_deliveries.last
    assert_equal "pending", delivery.status
    assert_equal @channel.id, delivery.channel_id
    assert_equal @conversation.id, delivery.message.conversation_id
    assert_equal message, delivery.message
  end

  test "is idempotent — same operation_key returns existing delivery" do
    key = "idempotent_test"
    message = @conversation.messages.create!(
      agent: @agent,
      author_name: @agent.name,
      content: "Hello!",
      direction: "outbound",
      delivery_status: "local"
    )

    first = MessageDeliveries::Send.call(
      conversation: @conversation,
      channel: @channel,
      agent: @agent,
      message: message,
      operation_key: key
    )

    assert_no_difference [ -> { @conversation.messages.count }, -> { @account.message_deliveries.count } ] do
      second = MessageDeliveries::Send.call(
        conversation: @conversation,
        channel: @channel,
        agent: @agent,
        message: message,
        operation_key: key
      )
      assert_equal first.id, second.id
    end
  end

  test "rejects inactive channel" do
    message = @conversation.messages.create!(
      agent: @agent,
      author_name: @agent.name,
      content: "Hello!",
      direction: "outbound",
      delivery_status: "local"
    )
    @channel.update!(active: false)

    assert_raises(Reservi::Errors::OperationError, match: /not active/) do
      MessageDeliveries::Send.call(
        conversation: @conversation,
        channel: @channel,
        agent: @agent,
        message: message,
        operation_key: "op_#{SecureRandom.hex(8)}"
      )
    end
  end
end
