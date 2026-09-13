require "test_helper"

class ConversationFields::UpdateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow.update!(current_version: flow_versions(:alpha_v1))
    @admin = memberships(:alpha_alice)
    @agent = agents(:alpha_alice_human)

    @account.field_definitions.create!(scope: "conversation", key: "budget", field_type: "number", position: 1, constraints: { "min" => 0 })
    @account.field_definitions.create!(scope: "conversation", key: "urgency", field_type: "single_choice", position: 2, options: [{ "key" => "low", "label" => "Low" }, { "key" => "high", "label" => "High" }])

    @conversation = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Test", email_address: "test@example.com" },
      agent: @agent,
      content: "Hello"
    )
  end

  test "updates conversation custom values" do
    ConversationFields::Update.call(
      conversation: @conversation,
      actor_membership: @admin,
      attributes: { budget: 500 }
    )
    @conversation.reload
    assert_equal 500, @conversation.custom_values["budget"]
  end

  test "invalid values raise error" do
    e = assert_raises(Reservi::Errors::OperationError) do
      ConversationFields::Update.call(
        conversation: @conversation,
        actor_membership: @admin,
        attributes: { budget: -100 }
      )
    end
    assert_match /at least 0/, e.message
  end

  test "invalid choice values raise error" do
    e = assert_raises(Reservi::Errors::OperationError) do
      ConversationFields::Update.call(
        conversation: @conversation,
        actor_membership: @admin,
        attributes: { urgency: "urgent" }
      )
    end
    assert_match /must be one of/i, e.message
  end

  test "zero persists for conversation fields" do
    ConversationFields::Update.call(
      conversation: @conversation,
      actor_membership: @admin,
      attributes: { budget: 0 }
    )
    @conversation.reload
    assert_equal 0, @conversation.custom_values["budget"]
  end

  test "only updates the target conversation" do
    conv2 = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Other", email_address: "other@example.com" },
      agent: @agent,
      content: "Hi"
    )
    ConversationFields::Update.call(
      conversation: @conversation,
      actor_membership: @admin,
      attributes: { budget: 1000 }
    )
    @conversation.reload
    conv2.reload
    assert_equal 1000, @conversation.custom_values["budget"]
    assert_nil conv2.custom_values["budget"]
  end

  test "undefined key is stored without validation" do
    ConversationFields::Update.call(
      conversation: @conversation,
      actor_membership: @admin,
      attributes: { undefined_field: "value" }
    )
    @conversation.reload
    assert_equal "value", @conversation.custom_values["undefined_field"]
  end

  test "updates multiple fields at once" do
    ConversationFields::Update.call(
      conversation: @conversation,
      actor_membership: @admin,
      attributes: { budget: 300, urgency: "low" }
    )
    @conversation.reload
    assert_equal 300, @conversation.custom_values["budget"]
    assert_equal "low", @conversation.custom_values["urgency"]
  end

  test "type mismatch is rejected" do
    e = assert_raises(Reservi::Errors::OperationError) do
      ConversationFields::Update.call(
        conversation: @conversation,
        actor_membership: @admin,
        attributes: { budget: "not_a_number" }
      )
    end
    assert_match /must be a number/i, e.message
  end
end