require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @token = SecureRandom.hex(16)
    @channel = @account.channels.create!(
      name: "Dev Channel",
      provider_type: "dev",
      inbound_token: @token
    )
    # Ensure a published flow exists for the webhook to use
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
  end

  test "inbound message creates conversation for new thread" do
    initial_conv_count = @account.conversations.count
    initial_thread_count = @channel.channel_threads.count

    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "thread_1", content: "I need help!", author_name: "Ahmed" },
      as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "accepted", body["status"]
    assert_equal initial_conv_count + 1, @account.conversations.count
    assert_equal initial_thread_count + 1, @channel.channel_threads.count

    thread = @channel.channel_threads.find_by(external_thread_id: "thread_1")
    assert thread.present?
    assert thread.conversation.messages.inbound.last.content.include?("I need help!")
  end

  test "second message on same thread uses existing conversation" do
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "thread_2", content: "First message", author_name: "Ahmed" },
      as: :json
    assert_response :success

    initial_conv_count = @account.conversations.count
    initial_thread_count = @channel.channel_threads.count

    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "thread_2", content: "Second message", author_name: "Ahmed" },
      as: :json
    assert_response :success

    assert_equal initial_conv_count, @account.conversations.count
    assert_equal initial_thread_count, @channel.channel_threads.count
    thread = @channel.channel_threads.find_by(external_thread_id: "thread_2")
    assert_equal 2, thread.conversation.messages.inbound.count
  end

  test "unauthorized token rejected" do
    post dev_webhook_inbound_url(token: "wrong_token"),
      params: { thread_id: "t1", content: "test" },
      as: :json

    assert_response :unauthorized
  end

  test "invalid JSON rejected" do
    post dev_webhook_inbound_url(token: @token),
      env: { "RAW_POST_DATA" => "not valid json" },
      headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unprocessable_content
  end

  test "delivery status callback updates delivery" do
    message = @account.conversations.first.messages.create!(
      author_name: "Test",
      content: "Hello",
      direction: "outbound",
      delivery_status: "sent"
    )
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: message,
      status: "sent",
      operation_key: "status_test",
      provider_message_id: "dev_msg_1_12345"
    )

    post dev_webhook_status_url(token: @token),
      params: { provider_message_id: "dev_msg_1_12345", status: "delivered" },
      as: :json

    assert_response :success

    delivery.reload
    assert_equal "delivered", delivery.status
    assert_equal "delivered", message.reload.delivery_status
  end

  test "inbound message evaluates rules on active conversation" do
    # Set up a rule on the webhook-created flow's stage
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "rule_test", content: "Assign me", author_name: "Bob" },
      as: :json
    assert_response :success

    thread = @channel.channel_threads.find_by(external_thread_id: "rule_test")
    conversation = thread.conversation

    # The flow has no rules, so evaluation should be a no-op
    # (no exception, no crash)
    assert conversation.active?
  end

  test "inbound message on completed conversation raises attention without error" do
    # Create a test conversation that's already completed
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "completed_test", content: "First", author_name: "Bob" },
      as: :json
    assert_response :success

    thread = @channel.channel_threads.find_by(external_thread_id: "completed_test")
    conversation = thread.conversation
    conversation.update!(process_status: "completed")

    # Send a second message — should raise attention but not crash
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "completed_test", content: "Hello again!", author_name: "Bob" },
      as: :json
    assert_response :success

    conversation.reload
    assert conversation.attention?
    assert_equal "completed", conversation.process_status
  end

  test "delivery status does not regress" do
    message = @account.conversations.first.messages.create!(
      author_name: "Test",
      content: "Hello",
      direction: "outbound",
      delivery_status: "delivered"
    )
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: message,
      status: "delivered",
      operation_key: "no_regress",
      provider_message_id: "dev_msg_2_12345"
    )

    # Try to regress from delivered → sent
    post dev_webhook_status_url(token: @token),
      params: { provider_message_id: "dev_msg_2_12345", status: "sent" },
      as: :json

    assert_response :success
    delivery.reload
    assert_equal "delivered", delivery.status
  end
end
