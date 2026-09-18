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

  test "panel endpoint returns the matching turbo frame" do
    conversation = conversations(:alpha_active)

    get account_conversation_panel_url(@account, conversation)

    assert_response :success
    assert_select "turbo-frame#conversation_panel"
    assert_select "h3", text: conversation.current_stage.label
    assert_select "form[action='#{account_conversation_reassign_path(@account, conversation)}']"
  end

  test "updates a conversation field and returns to the workspace" do
    conversation = conversations(:alpha_active)
    @account.field_definitions.create!(scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1)
    conversation.current_stage.update!(blocks: [ { "type" => "field", "key" => "budget" } ])

    patch account_conversation_field_url(@account, conversation), params: { key: "budget", value: "500" }

    assert_redirected_to account_conversation_path(@account, conversation)
    assert_equal 500, conversation.reload.custom_values["budget"]
  end

  test "rejects a field that is not configured in the current stage" do
    conversation = conversations(:alpha_active)
    @account.field_definitions.create!(scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1)

    patch account_conversation_field_url(@account, conversation), params: { key: "budget", value: "500" }

    assert_redirected_to account_conversation_path(@account, conversation)
    assert_equal "That field is not available in the current stage.", flash[:alert]
    assert_nil conversation.reload.custom_values["budget"]
  end

  test "field mutation evaluates completion and advances the stage" do
    conversation = conversations(:alpha_active)
    first_stage = conversation.current_stage
    @account.field_definitions.create!(scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1)
    first_stage.update!(
      blocks: [ { "type" => "field", "key" => "budget" } ],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } }
    )
    next_stage = first_stage.flow_version.stages.create!(
      key: "follow_up", label: "Follow up", position: 2,
      blocks: [], rules: [], completion: { "literal" => false }
    )

    patch account_conversation_field_url(@account, conversation), params: { key: "budget", value: "500" }

    assert_redirected_to account_conversation_path(@account, conversation)
    assert_equal next_stage.id, conversation.reload.current_stage_id
    assert_equal 1, conversation.stage_transitions.where(from_stage: first_stage, to_stage: next_stage).count
  end

  test "rejects an appointment role outside the current stage" do
    conversation = conversations(:alpha_active)

    assert_no_difference -> { conversation.appointments.count } do
      post account_conversation_appointments_url(@account, conversation), params: {
        role_key: "forged_role", starts_at: "2026-09-20T10:00"
      }
    end

    assert_redirected_to account_conversation_path(@account, conversation)
    assert_equal "That appointment is not available in the current stage.", flash[:alert]
  end

  test "rejects a nonexistent local appointment time" do
    conversation = conversations(:alpha_active)
    conversation.current_stage.update!(blocks: [ { "type" => "appointment", "role_key" => "consultation" } ])
    @account.update!(timezone: "America/New_York")

    assert_no_difference -> { conversation.appointments.count } do
      post account_conversation_appointments_url(@account, conversation), params: {
        role_key: "consultation", starts_at: "2026-03-08T02:30"
      }
    end

    assert_redirected_to account_conversation_path(@account, conversation)
    assert_equal "Choose an unambiguous local time.", flash[:alert]
  end

  test "panel field input has an associated label" do
    conversation = conversations(:alpha_active)
    definition = @account.field_definitions.create!(scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1)
    conversation.current_stage.update!(blocks: [ { "type" => "field", "key" => "budget" } ])

    get account_conversation_panel_url(@account, conversation)

    input_id = "conversation_field_#{definition.id}"
    assert_select "label[for='#{input_id}']", text: /Budget/
    assert_select "input##{input_id}[type='number']"
  end

  test "panel offers a replacement after an appointment is cancelled" do
    conversation = conversations(:alpha_active)
    conversation.current_stage.update!(blocks: [ { "type" => "appointment", "role_key" => "consultation" } ])
    appointment = Appointments::Create.call(
      conversation:,
      role_key: "consultation",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      timezone: @account.timezone,
      scheduled_agent: @alice
    )
    Appointments::Cancel.call(appointment:)

    get account_conversation_panel_url(@account, conversation)

    assert_select "p", text: "Previous appointment cancelled"
    # The new booking UI renders after cancellation:
    assert_select "[data-controller='appointment-booking']"
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
        content: "Thanks for your inquiry!"
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
        content: "Internal note about this customer"
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
