require "test_helper"

class Reservi::Channels::DevAdapterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @channel = @account.channels.create!(
      name: "Test Dev",
      provider_type: "dev",
      inbound_token: SecureRandom.hex(16)
    )
    @conversation = conversations(:alpha_active)
    @agent = agents(:alpha_alice_human)
    @message = @conversation.messages.create!(
      agent: @agent,
      author_name: @agent.name,
      content: "Test message",
      direction: "outbound",
      delivery_status: "local"
    )
    @delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "test_send_#{SecureRandom.hex(8)}"
    )
  end

  test "sends successfully" do
    result = Reservi::Channels::DevAdapter.new.send_message(message_delivery: @delivery)
    assert_equal "sent", result[:status]
    assert result[:provider_message_id].present?
    assert_nil result[:error]
  end

  test "simulates failure" do
    @message.update!(content: "This will SIMULATE_FAILURE")
    result = Reservi::Channels::DevAdapter.new.send_message(message_delivery: @delivery)
    assert_equal "failed", result[:status]
    assert result[:error].present?
  end

  test "simulates timeout" do
    @message.update!(content: "This will SIMULATE_TIMEOUT")
    result = Reservi::Channels::DevAdapter.new.send_message(message_delivery: @delivery)
    assert_equal "unknown", result[:status]
    assert result[:provider_message_id].present?
  end

  test "adapter resolution returns instance" do
    adapter = Reservi::Channels::BaseAdapter.for_provider("dev")
    assert_instance_of Reservi::Channels::DevAdapter, adapter
  end

  test "unknown provider raises" do
    assert_raises(ArgumentError) do
      Reservi::Channels::BaseAdapter.for_provider("nonexistent")
    end
  end
end
