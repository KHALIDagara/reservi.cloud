require "test_helper"

class Reservi::Rules::SendMessageActionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @alice = agents(:alpha_alice_human)

    # Start unowned
    @conversation.update!(owner: nil) if @conversation.owner_id.present?

    @channel = @account.channels.create!(
      name: "Test Channel",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16)
    )
    @context = { executing_agent: nil }
  end

  test "queues a message via rule action" do
    result = Reservi::Rules::SendMessageAction.call(
      { "type" => "send_message", "content" => "Your request is being processed.", "channel_id" => @channel.id },
      conversation: @conversation, context: @context
    )

    assert_equal "queued", result[:status]
    assert result[:delivery_id].present?
    assert result[:message_id].present?
  end

  test "fails without content" do
    result = Reservi::Rules::SendMessageAction.call(
      { "type" => "send_message", "channel_id" => @channel.id },
      conversation: @conversation, context: @context
    )

    assert_equal "failed", result[:status]
    assert_match /Missing content/, result[:error]
  end

  test "fails without active channel" do
    result = Reservi::Rules::SendMessageAction.call(
      { "type" => "send_message", "content" => "Hello", "channel_id" => 999999 },
      conversation: @conversation, context: @context
    )

    assert_equal "failed", result[:status]
    assert_match /No active channel/, result[:error]
  end
end
