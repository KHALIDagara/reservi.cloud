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

  # -- Dev webhook tests (unchanged)

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
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "rule_test", content: "Assign me", author_name: "Bob" },
      as: :json
    assert_response :success

    thread = @channel.channel_threads.find_by(external_thread_id: "rule_test")
    conversation = thread.conversation
    assert conversation.active?
  end

  test "inbound message on completed conversation raises attention without error" do
    post dev_webhook_inbound_url(token: @token),
      params: { thread_id: "completed_test", content: "First", author_name: "Bob" },
      as: :json
    assert_response :success

    thread = @channel.channel_threads.find_by(external_thread_id: "completed_test")
    conversation = thread.conversation
    conversation.update!(process_status: "completed")

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

    post dev_webhook_status_url(token: @token),
      params: { provider_message_id: "dev_msg_2_12345", status: "sent" },
      as: :json

    assert_response :success
    delivery.reload
    assert_equal "delivered", delivery.status
  end

  # -- WhatsApp webhook via phone-number-based URL (new pattern) --

  test "failed domain processing marks receipt processed (prevents duplicated delivery)" do
    beta = accounts(:beta)
    display_phone = "5511998765432"
    whatsapp = beta.channels.create!(
      name: "WhatsApp",
      provider_type: "whatsapp",
      provider_external_id: "phone-test",
      inbound_token: SecureRandom.urlsafe_base64(24),
      provider_config: {
        "phone_number_id" => "phone-test",
        "display_phone_number" => display_phone,
        "webhook_verify_token" => "verify-me"
      }
    )
    payload = {
      entry: [ { changes: [ { value: {
        metadata: { phone_number_id: "phone-test", display_phone_number: display_phone },
        contacts: [ { profile: { name: "Nora" }, wa_id: "212600000000" } ],
        messages: [ { from: "212600000000", id: "wamid.retry-1", text: { body: "Hello" }, type: "text" } ]
      } } ] } ]
    }.to_json

    # Domain processing should fail (beta has no published flow),
    # but the receipt should still be marked processed (R21).
    post whatsapp_webhook_events_url(phone_number: "+#{display_phone}"),
      env: { "RAW_POST_DATA" => payload },
      headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :success

    receipt = whatsapp.reload.webhook_receipts.last
    assert receipt.present?, "Receipt should exist even when domain processing fails"
    assert receipt.processed_at.present?, "Receipt should be marked processed (R21: prevent duplicate delivery)"
  end

  test "phone-number-based WhatsApp webhook verifies and processes inbound message" do
    display_phone = "5511998765432"
    whatsapp = @account.channels.create!(
      name: "WhatsApp",
      provider_type: "whatsapp",
      provider_external_id: "phone-123",
      inbound_token: SecureRandom.urlsafe_base64(24),
      provider_config: {
        "phone_number_id" => "phone-123",
        "display_phone_number" => display_phone,
        "webhook_verify_token" => "verify-me"
      }
    )
    payload = {
      entry: [ { changes: [ { value: {
        messaging_product: "whatsapp",
        metadata: { phone_number_id: "phone-123", display_phone_number: display_phone },
        contacts: [ { profile: { name: "Nora" }, wa_id: "212600000000" } ],
        messages: [ { from: "212600000000", id: "wamid.global-1", text: { body: "Hello" }, type: "text" } ]
      } } ] } ]
    }.to_json

    # Verify
    get whatsapp_webhook_verify_url(phone_number: "+#{display_phone}"),
      params: { "hub.mode" => "subscribe", "hub.verify_token" => "verify-me", "hub.challenge" => "challenge" }
    assert_response :success
    assert_equal "challenge", response.body

    # Inbound message
    assert_difference -> { whatsapp.reload.channel_threads.count }, 1 do
      post whatsapp_webhook_events_url(phone_number: "+#{display_phone}"),
        env: { "RAW_POST_DATA" => payload },
        headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :success
    assert_equal "Hello", whatsapp.channel_threads.last.conversation.messages.last.content
  end

  test "whatsapp events rejected for unknown phone number" do
    payload = {
      entry: [ { changes: [ { value: {
        metadata: { phone_number_id: "nonexistent" },
        contacts: [ { profile: { name: "X" }, wa_id: "212000000000" } ],
        messages: [ { from: "212000000000", id: "wamid.x-1", text: { body: "hi" }, type: "text" } ]
      } } ] } ]
    }.to_json

    post whatsapp_webhook_events_url(phone_number: "+99999999999"),
      env: { "RAW_POST_DATA" => payload },
      headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :not_found
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