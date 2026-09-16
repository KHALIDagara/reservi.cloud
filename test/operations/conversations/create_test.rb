require "test_helper"

class Conversations::CreateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @agent = agents(:alpha_alice_human)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
  end

  test "creates customer, conversation, and initial message atomically" do
    conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Charlie", email_address: "charlie@example.com" },
      agent: @agent,
      content: "I need help with my booking."
    )

    assert conversation.persisted?
    assert_equal @account, conversation.account
    assert_equal "active", conversation.process_status
    assert_equal @agent.id, conversation.owner_id
    assert conversation.attention?
    assert conversation.first_attention_at.present?
    assert conversation.last_activity_at.present?

    customer = conversation.customer
    assert_equal "Charlie", customer.name
    assert_equal "charlie@example.com", customer.email_address

    assert_equal 1, conversation.messages.count
    message = conversation.messages.first
    assert_equal "inbound", message.direction
    assert_equal "I need help with my booking.", message.content
    assert_equal @agent.name, message.author_name
  end

  test "finds existing customer by email" do
    existing = customers(:alpha_wilma)

    conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Wilma Customer", email_address: "wilma@example.com" },
      agent: @agent,
      content: "Wilma again!"
    )

    assert_equal existing.id, conversation.customer_id
  end

  test "fails when Flow has no published version" do
    @flow.update!(current_version: nil)

    e = assert_raises(Reservi::Errors::OperationError) do
      Conversations::Create.call(
        account: @account,
        customer_attributes: { name: "No Version" },
        agent: @agent,
        content: "Test"
      )
    end
    assert_match /no published version/, e.message
  end
end
