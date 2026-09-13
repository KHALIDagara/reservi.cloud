require "test_helper"

class Conversations::UnclaimTest < ActiveSupport::TestCase
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

  test "owner can release their conversation" do
    Conversations::Unclaim.call(conversation: @conversation, agent: @alice)
    @conversation.reload
    assert_nil @conversation.owner_id
  end

  test "non-owner cannot release" do
    bob = agents(:alpha_bob_human)
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Conversations::Unclaim.call(conversation: @conversation, agent: bob)
    end
    assert_match /not the current owner/, e.message
  end
end