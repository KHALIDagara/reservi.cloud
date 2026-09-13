require "test_helper"

class Messages::CreateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)

    @alice = agents(:alpha_alice_human)
    @conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Test", email_address: "test@example.com" },
      agent: @alice,
      content: "Initial"
    )
  end

  test "adds an outbound message and updates activity" do
    message = Messages::Create.call(
      conversation: @conversation,
      agent: @alice,
      content: "Thanks for reaching out!",
      direction: "outbound"
    )

    assert message.persisted?
    assert_equal "outbound", message.direction
    assert_equal "Thanks for reaching out!", message.content
    assert_equal @alice.name, message.author_name
    assert_equal "local", message.delivery_status
  end

  test "adds an inbound message" do
    message = Messages::Create.call(
      conversation: @conversation,
      agent: @alice,
      content: "Can you help me?",
      direction: "inbound"
    )

    assert message.persisted?
    assert_equal "inbound", message.direction
  end
end