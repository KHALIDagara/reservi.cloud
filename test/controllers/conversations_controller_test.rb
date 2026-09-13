require "test_helper"

class Accounts::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
    @alice = agents(:alpha_alice_human)
    @customer = customers(:alpha_wilma)
  end

  test "new conversation form renders" do
    get new_account_conversation_url(@account)
    assert_response :success
    assert_select "h1", text: "New conversation"
  end

  test "create conversation with new customer" do
    assert_difference -> { @account.conversations.count } => 1,
                      -> { @account.customers.count } => 1 do
      post account_conversations_url(@account), params: {
        conversation: {
          name: "Omar",
          email_address: "omar@example.com",
          phone: "+212600000000",
          initial_message: "I need a service please"
        }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "create conversation with existing customer by email" do
    assert_difference -> { @account.conversations.count } => 1,
                      -> { @account.customers.count } => 0 do
      post account_conversations_url(@account), params: {
        conversation: {
          name: @customer.name,
          email_address: @customer.email_address,
          initial_message: "Following up"
        }
      }
    end

    assert_response :redirect
  end

  test "show conversation renders messages and notes" do
    # First create a conversation via the UI
    post account_conversations_url(@account), params: {
      conversation: {
        name: "Show Test",
        email_address: "show@example.com",
        initial_message: "Initial msg"
      }
    }
    conversation = @account.conversations.last

    get account_conversation_url(@account, conversation)
    assert_response :success
    assert_select "h1", text: "Show Test"
  end

  test "create message on conversation" do
    conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Msg Test" },
      agent: @alice,
      content: "Hello"
    )

    assert_difference -> { conv.messages.count } => 1 do
      post account_conversation_messages_url(@account, conv), params: {
        message: { content: "Thanks for your inquiry!" }
      }
    end

    assert_response :redirect
  end

  test "create note on conversation" do
    conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Note Test" },
      agent: @alice,
      content: "Hello"
    )

    assert_difference -> { conv.notes.count } => 1 do
      post account_conversation_notes_url(@account, conv), params: {
        note: { content: "Internal note about this customer" }
      }
    end

    assert_response :redirect
  end

  test "claim an unowned conversation" do
    conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Claim Test" },
      agent: @alice,
      content: "Hello"
    )
    conv.update!(owner: nil)

    post account_conversation_claim_url(@account, conv)
    assert_response :redirect
    conv.reload
    assert_equal @alice.id, conv.owner_id
  end

  test "cancel a conversation" do
    conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Cancel Test" },
      agent: @alice,
      content: "Hello"
    )

    post account_conversation_cancel_url(@account, conv), params: { reason: "Test cancellation" }
    assert_response :redirect
    conv.reload
    assert_equal "cancelled", conv.process_status
  end
end