require "test_helper"

class Conversations::ClaimTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)

    @alice = agents(:alpha_alice_human)
    @bob = agents(:alpha_bob_human)

    # Create an unowned conversation
    @conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Unowned", email_address: "unowned@example.com" },
      agent: @alice,
      content: "Initial message"
    )
    # Release ownership so it's truly unowned
    @conversation.update!(owner: nil)
  end

  test "agent can claim an unowned conversation" do
    Conversations::Claim.call(conversation: @conversation, agent: @bob)
    @conversation.reload
    assert_equal @bob.id, @conversation.owner_id
  end

  test "claiming an already-owned conversation fails" do
    @conversation.update!(owner: @alice)

    e = assert_raises(Reservi::Errors::OperationError) do
      Conversations::Claim.call(conversation: @conversation, agent: @bob)
    end
    assert_match /already has an owner/, e.message
  end

  test "concurrent claims produce exactly one owner" do
    results = []
    threads = 3.times.map do |i|
      agent = i == 0 ? @alice : @bob
      Thread.new do
        Conversations::Claim.call(conversation: @conversation, agent: agent)
      rescue Reservi::Errors::OperationError
        nil
      end
    end
    results = threads.map(&:value).compact

    assert_equal 1, results.length
    @conversation.reload
    assert @conversation.owner_id.present?
  end
end
