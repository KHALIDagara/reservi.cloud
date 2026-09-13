require "test_helper"

class Conversations::CancelTest < ActiveSupport::TestCase
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

  test "cancels an active conversation and clears owner" do
    Conversations::Cancel.call(conversation: @conversation, agent: @alice, reason: "Duplicate request")
    @conversation.reload
    assert_equal "cancelled", @conversation.process_status
    assert_nil @conversation.owner_id
  end

  test "cancelling an already cancelled conversation fails" do
    @conversation.update!(process_status: "cancelled")
    e = assert_raises(Reservi::Errors::OperationError) do
      Conversations::Cancel.call(conversation: @conversation, agent: @alice, reason: "Again")
    end
    assert_match /already cancelled/, e.message
  end
end