require "test_helper"

class WebhooksControllerMetaTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow.update!(current_version: flow_versions(:alpha_v1))

    @token = SecureRandom.hex(16)
    @channel = @account.channels.create!(
      name: "WhatsApp Chan",
      provider_type: "whatsapp",
      inbound_token: @token,
      provider_config: {
        "phone_number_id" => "123456789",
        "access_token" => "test_token",
        "webhook_verify_token" => "my_verify_123"
      }
    )
  end

  # ---- WhatsApp verification ----

  test "whatsapp verify with correct token returns challenge" do
    get whatsapp_webhook_verify_url(token: @token), params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "my_verify_123",
      "hub.challenge" => "challenge_abc"
    }

    assert_response :ok
    assert_equal "challenge_abc", response.body
  end

  test "whatsapp verify with wrong verify_token returns forbidden" do
    get whatsapp_webhook_verify_url(token: @token), params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong_token",
      "hub.challenge" => "challenge_abc"
    }

    assert_response :forbidden
  end

  test "whatsapp verify with missing challenge returns forbidden" do
    get whatsapp_webhook_verify_url(token: @token), params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "my_verify_123"
    }

    assert_response :forbidden
  end

  test "whatsapp verify with bad token returns not_found" do
    get whatsapp_webhook_verify_url(token: "bad_token"), params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "my_verify_123",
      "hub.challenge" => "test"
    }

    assert_response :not_found
  end

  # ---- WhatsApp events ----

  test "whatsapp event creates conversation and message" do
    initial_conv_count = @account.conversations.count
    initial_msg_count = @account.conversations.sum { |c| c.messages.count }

    wa_payload = {
      "entry" => [ {
        "id" => "WHATSAPP_BUSINESS_ACCOUNT_ID",
        "changes" => [ {
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => {
              "display_phone_number" => "5511999999999",
              "phone_number_id" => "123456789"
            },
            "contacts" => [ {
              "profile" => { "name" => "Ahmed Salem" },
              "wa_id" => "5511988888888"
            } ],
            "messages" => [ {
              "from" => "5511988888888",
              "id" => "wamid.MetaEvent001",
              "timestamp" => "1700000000",
              "text" => { "body" => "Hello from WhatsApp!" },
              "type" => "text"
            } ]
          }
        } ]
      } ]
    }

    post whatsapp_webhook_events_url(token: @token),
      params: wa_payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok

    # Verify conversation was created
    assert_equal initial_conv_count + 1, @account.conversations.count

    thread = @channel.channel_threads.find_by(external_thread_id: "5511988888888")
    assert thread.present?
    assert_equal "Ahmed Salem", thread.external_contact_name

    conv = thread.conversation
    assert_equal @account.reload.conversations.count - initial_conv_count, 1
    assert conv.messages.inbound.last.content.include?("Hello from WhatsApp!")

    # Verify webhook receipt was created
    receipt = WebhookReceipt.find_by(channel: @channel, provider_event_id: "wamid.MetaEvent001")
    assert receipt.present?
    assert_equal "message", receipt.event_type
  end

  test "whatsapp event deduplicates via WebhookReceipt" do
    wa_payload = {
      "entry" => [ {
        "id" => "WHATSAPP_BUSINESS_ACCOUNT_ID",
        "changes" => [ {
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => {
              "display_phone_number" => "5511999999999",
              "phone_number_id" => "123456789"
            },
            "contacts" => [ {
              "profile" => { "name" => "Ahmed Salem" },
              "wa_id" => "5511988888888"
            } ],
            "messages" => [ {
              "from" => "5511988888888",
              "id" => "wamid.DuplicateEvent",
              "timestamp" => "1700000000",
              "text" => { "body" => "First arrival" },
              "type" => "text"
            } ]
          }
        } ]
      } ]
    }

    # First request
    initial_conv_count = @account.conversations.count
    post whatsapp_webhook_events_url(token: @token),
      params: wa_payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
    assert_equal initial_conv_count + 1, @account.conversations.count

    thread = @channel.channel_threads.find_by(external_thread_id: "5511988888888")
    msg_count = thread.conversation.messages.count

    # Second request with same event ID
    post whatsapp_webhook_events_url(token: @token),
      params: wa_payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok
    # No new conversation created
    assert_equal initial_conv_count + 1, @account.conversations.count
    # No new message created (deduplicated)
    assert_equal msg_count, thread.conversation.reload.messages.count
  end

  test "whatsapp event with message status updates delivery" do
    customer = @account.customers.first
    conv = @account.conversations.first
    msg = conv.messages.create!(
      author_name: "Agent",
      content: "Hello",
      direction: "outbound",
      delivery_status: "sent"
    )
    delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: msg,
      status: "sent",
      operation_key: "wa_status_test",
      provider_message_id: "wamid.StatusTarget"
    )

    status_payload = {
      "entry" => [ {
        "id" => "WHATSAPP_BUSINESS_ACCOUNT_ID",
        "changes" => [ {
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => {
              "display_phone_number" => "5511999999999",
              "phone_number_id" => "123456789"
            },
            "statuses" => [ {
              "id" => "wamid.StatusTarget",
              "status" => "delivered",
              "timestamp" => "1700000100",
              "recipient_id" => "5511988888888"
            } ]
          }
        } ]
      } ]
    }

    post whatsapp_webhook_events_url(token: @token),
      params: status_payload.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :ok

    delivery.reload
    assert_equal "delivered", delivery.status
    assert_equal "delivered", msg.reload.delivery_status
  end

  # ---- Instagram verification ----

  test "instagram verify returns OK" do
    # Instagram verification does not use the subscribe/verify token protocol
    # but should still respond
    get instagram_webhook_verify_url(token: @token)

    assert_response :ok
  end

  # ---- WebhookReceipt model tests ----

  test "webhook receipt deduplication" do
    receipt1 = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: "test_event_001",
      event_type: "message",
      payload: { "test" => true }
    )
    assert receipt1.persisted?

    receipt2 = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: "test_event_001",
      event_type: "message",
      payload: { "test" => false }
    )
    assert receipt2.persisted?
    assert_not receipt2.previously_new_record?
  end
end
