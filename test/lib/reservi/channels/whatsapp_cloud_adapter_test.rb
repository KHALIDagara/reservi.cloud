require "test_helper"
require "net/http"
require "minitest/mock"

class Reservi::Channels::WhatsappCloudAdapterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow.update!(current_version: flow_versions(:alpha_v1))

    @channel = @account.channels.create!(
      name: "WhatsApp",
      provider_type: "whatsapp",
      inbound_token: SecureRandom.hex(16),
      provider_config: {
        "phone_number_id" => "123456789",
        "access_token" => "test_token",
        "webhook_verify_token" => "verify_abc"
      }
    )

    @customer = @account.customers.create!(name: "Test Customer")
    @conversation = @account.conversations.create!(
      customer: @customer,
      flow_version: flow_versions(:alpha_v1),
      current_stage: stages(:alpha_stage1),
      process_status: "active",
      custom_values: {}
    )
    @thread = @channel.channel_threads.create!(
      account: @account,
      conversation: @conversation,
      external_thread_id: "5511999999999",
      external_contact_id: "5511999999999",
      external_contact_name: "Test Customer"
    )

    @agent = agents(:alpha_alice_human)
    @message = @conversation.messages.create!(
      agent: @agent,
      author_name: @agent.name,
      content: "Hello!",
      direction: "outbound",
      delivery_status: "local"
    )
    @delivery = @account.message_deliveries.create!(
      channel: @channel,
      message: @message,
      status: "pending",
      operation_key: "wa_send_#{SecureRandom.hex(8)}"
    )
  end

  # ---- normalize_payload tests ----

  test "normalizes inbound message payload" do
    payload = {
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
              "id" => "wamid.HBgM...",
              "timestamp" => "1700000000",
              "text" => { "body" => "I need help with my garden" },
              "type" => "text"
            } ]
          }
        } ]
      } ]
    }

    result = Reservi::Channels::WhatsappCloudAdapter.normalize_payload(payload)
    assert_equal "message", result[:type]
    assert_equal "wamid.HBgM...", result[:provider_message_id]
    assert_equal "5511988888888", result[:from]
    assert_equal "Ahmed Salem", result[:contact_name]
    assert_equal "I need help with my garden", result[:body]
  end

  test "normalizes delivery status payload" do
    payload = {
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
              "id" => "wamid.HBgM...",
              "status" => "delivered",
              "timestamp" => "1700000100",
              "recipient_id" => "5511988888888"
            } ]
          }
        } ]
      } ]
    }

    result = Reservi::Channels::WhatsappCloudAdapter.normalize_payload(payload)
    assert_equal "message_status", result[:type]
    assert_equal "wamid.HBgM...", result[:provider_message_id]
    assert_equal "delivered", result[:status]
    assert_equal "5511988888888", result[:recipient_id]
  end

  test "normalize_payload returns nil for empty payload" do
    assert_nil Reservi::Channels::WhatsappCloudAdapter.normalize_payload({})
    assert_nil Reservi::Channels::WhatsappCloudAdapter.normalize_payload({ "entry" => [] })
  end

  # ---- send_message tests ----

  test "send_message returns sent status" do
    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [ true ])
    mock_http.expect(:open_timeout=, nil, [ 10 ])
    mock_http.expect(:read_timeout=, nil, [ 30 ])
    mock_http.expect(:request, Net::HTTPOK.new("1.1", "200", "OK").tap { |r|
      r.instance_variable_set(:@body, {
        "messaging_product" => "whatsapp",
        "contacts" => [ { "input" => "5511988888888", "wa_id" => "5511988888888" } ],
        "messages" => [ { "id" => "wamid.HBgM..." } ]
      }.to_json)
      r.instance_variable_set(:@read, true)
    }, [ Net::HTTP::Post ])

    Net::HTTP.stub(:new, mock_http) do
      result = Reservi::Channels::WhatsappCloudAdapter.new.send_message(delivery: @delivery)
      assert_equal "sent", result[:status]
      assert_equal "wamid.HBgM...", result[:provider_message_id]
    end
  end

  test "send_message returns failed on HTTP error" do
    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [ true ])
    mock_http.expect(:open_timeout=, nil, [ 10 ])
    mock_http.expect(:read_timeout=, nil, [ 30 ])
    mock_http.expect(:request, Net::HTTPBadRequest.new("1.1", "400", "Bad Request").tap { |r|
      r.instance_variable_set(:@body, {
        "error" => { "message" => "Invalid OAuth access token", "type" => "OAuthException", "code" => 190 }
      }.to_json)
      r.instance_variable_set(:@read, true)
    }, [ Net::HTTP::Post ])

    Net::HTTP.stub(:new, mock_http) do
      result = Reservi::Channels::WhatsappCloudAdapter.new.send_message(delivery: @delivery)
      assert_equal "failed", result[:status]
      assert_equal "Invalid OAuth access token", result[:error]
    end
  end

  test "send_message returns failed on network error" do
    broken = ->(*args) { raise Net::OpenTimeout, "execution expired" }
    Net::HTTP.stub(:new, broken) do
      result = Reservi::Channels::WhatsappCloudAdapter.new.send_message(delivery: @delivery)
      assert_equal "failed", result[:status]
      assert_match(/execution expired/, result[:error])
    end
  end
end
