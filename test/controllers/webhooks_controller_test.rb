require "test_helper"
require "openssl"

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

  test "failed domain processing leaves receipt unprocessed for retry" do
    # Use beta account — it does not have its flow's current_version set by
    # the shared dev-channel setup, so the WhatsApp inbound will fail.
    beta = accounts(:beta)
    whatsapp = beta.channels.create!(
      name: "WhatsApp",
      provider_type: "whatsapp",
      provider_external_id: "phone-test",
      inbound_token: SecureRandom.urlsafe_base64(24),
      provider_config: { "phone_number_id" => "phone-test" }
    )
    payload = {
      object: "whatsapp_business_account",
      entry: [ { changes: [ { value: {
        metadata: { phone_number_id: "phone-test" },
        contacts: [ { profile: { name: "Nora" }, wa_id: "212600000000" } ],
        messages: [ { from: "212600000000", id: "wamid.retry-1", text: { body: "Hello" }, type: "text" } ]
      } } ] } ]
    }.to_json

    with_env("WHATSAPP_APP_SECRET" => "whatsapp-secret") do
      signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'whatsapp-secret', payload)}"

      # First delivery: receipt created, processed_at stays nil
      assert_difference -> { whatsapp.webhook_receipts.count }, 1 do
        post meta_whatsapp_webhook_events_url,
          env: { "RAW_POST_DATA" => payload },
          headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => signature }
      end
      assert_response :success
      receipt = whatsapp.webhook_receipts.last
      assert_nil receipt.processed_at, "Receipt should not be marked processed after domain failure"

      # Second delivery: receipt exists but unprocessed, should retry
      post meta_whatsapp_webhook_events_url,
        env: { "RAW_POST_DATA" => payload },
        headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => signature }
      assert_response :success
    end
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


  test "global WhatsApp webhook verifies and resolves its channel from signed provider identity" do
    whatsapp = @account.channels.create!(
      name: "WhatsApp",
      provider_type: "whatsapp",
      provider_external_id: "phone-123",
      inbound_token: SecureRandom.urlsafe_base64(24),
      provider_config: { "phone_number_id" => "phone-123", "webhook_verify_token" => "verify-me" }
    )
    payload = {
      object: "whatsapp_business_account",
      entry: [ { changes: [ { value: {
        metadata: { phone_number_id: "phone-123" },
        contacts: [ { profile: { name: "Nora" }, wa_id: "212600000000" } ],
        messages: [ { from: "212600000000", id: "wamid.global-1", text: { body: "Hello" }, type: "text" } ]
      } } ] } ]
    }.to_json

    with_env("WHATSAPP_APP_SECRET" => "whatsapp-secret", "META_WEBHOOK_VERIFY_TOKEN" => "verify-me") do
      get meta_whatsapp_webhook_verify_url,
        params: { "hub.mode" => "subscribe", "hub.verify_token" => "verify-me", "hub.challenge" => "challenge" }
      assert_response :success
      assert_equal "challenge", response.body

      signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'whatsapp-secret', payload)}"
      assert_difference -> { whatsapp.channel_threads.count }, 1 do
        post meta_whatsapp_webhook_events_url,
          env: { "RAW_POST_DATA" => payload },
          headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => signature }
      end
    end

    assert_response :success
    assert_equal "Hello", whatsapp.channel_threads.last.conversation.messages.last.content
  end

  test "global Instagram webhook rejects a bad signature" do
    instagram = @account.channels.create!(
      name: "Instagram",
      provider_type: "instagram",
      provider_external_id: "ig-123",
      inbound_token: SecureRandom.urlsafe_base64(24),
      provider_config: { "instagram_id" => "ig-123" }
    )
    payload = { object: "instagram", entry: [ { id: "ig-123", messaging: [] } ] }.to_json

    with_env("INSTAGRAM_APP_SECRET" => "instagram-secret") do
      assert_no_difference -> { instagram.webhook_receipts.count } do
        post meta_instagram_webhook_events_url,
          env: { "RAW_POST_DATA" => payload },
          headers: { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => "sha256=wrong" }
      end
    end

    assert_response :unauthorized
  end

  private

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
