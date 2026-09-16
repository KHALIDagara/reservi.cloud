require "test_helper"
require "net/http"
require "minitest/mock"

class Reservi::Channels::InstagramAdapterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow.update!(current_version: flow_versions(:alpha_v1))

    @channel = @account.channels.create!(
      name: "Instagram",
      provider_type: "instagram",
      inbound_token: SecureRandom.hex(16),
      provider_config: {
        "instagram_id" => "17841400000000000",
        "access_token" => "test_token",
        "webhook_verify_token" => "verify_xyz"
      }
    )

    @customer = @account.customers.create!(name: "Insta Customer")
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
      external_thread_id: "17841400000000001",
      external_contact_id: "17841400000000001",
      external_contact_name: "Insta Customer"
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
      operation_key: "ig_send_#{SecureRandom.hex(8)}"
    )
  end

  # ---- normalize_payload tests ----

  test "normalizes Instagram message payload" do
    payload = [{
      "messaging" => [{
        "sender" => { "id" => "17841400000000001" },
        "recipient" => { "id" => "17841400000000000" },
        "timestamp" => 1700000000000,
        "message" => {
          "mid" => "aWdfZAG1hZ...",
          "text" => "Do you have garden services?"
        }
      }]
    }]

    result = Reservi::Channels::InstagramAdapter.normalize_payload(payload)
    assert_equal "message", result[:type]
    assert_equal "aWdfZAG1hZ...", result[:provider_message_id]
    assert_equal "17841400000000001", result[:from]
    assert_equal "Do you have garden services?", result[:body]
  end

  test "normalizes Instagram read receipt" do
    payload = [{
      "messaging" => [{
        "sender" => { "id" => "17841400000000001" },
        "recipient" => { "id" => "17841400000000000" },
        "timestamp" => 1700000001000,
        "read" => {
          "mid" => "aWdfZAG1hZ..."
        }
      }]
    }]

    result = Reservi::Channels::InstagramAdapter.normalize_payload(payload)
    assert_equal "message_status", result[:type]
    assert_equal "aWdfZAG1hZ...", result[:provider_message_id]
    assert_equal "read", result[:status]
  end

  test "normalize_payload returns nil for empty payload" do
    assert_nil Reservi::Channels::InstagramAdapter.normalize_payload([])
    assert_nil Reservi::Channels::InstagramAdapter.normalize_payload([{}])
  end

  test "normalize_payload handles non-array input" do
    payload = {
      "messaging" => [{
        "sender" => { "id" => "17841400000000001" },
        "message" => { "mid" => "test_mid", "text" => "Hello" },
        "timestamp" => 1700000000000
      }]
    }

    result = Reservi::Channels::InstagramAdapter.normalize_payload(payload)
    assert_equal "message", result[:type]
    assert_equal "test_mid", result[:provider_message_id]
  end

  # ---- send_message tests ----

  test "send_message returns sent status" do
    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:open_timeout=, nil, [10])
    mock_http.expect(:read_timeout=, nil, [30])
    mock_http.expect(:request, Net::HTTPOK.new("1.1", "200", "OK").tap { |r|
      r.instance_variable_set(:@body, {
        "recipient_id" => "17841400000000001",
        "message_id" => "aWdfZAG1hZ..."
      }.to_json)
      r.instance_variable_set(:@read, true)
    }, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = Reservi::Channels::InstagramAdapter.new.send_message(delivery: @delivery)
      assert_equal "sent", result[:status]
      assert_equal "aWdfZAG1hZ...", result[:provider_message_id]
    end
  end

  test "send_message returns failed on HTTP error" do
    mock_http = Minitest::Mock.new
    mock_http.expect(:use_ssl=, nil, [true])
    mock_http.expect(:open_timeout=, nil, [10])
    mock_http.expect(:read_timeout=, nil, [30])
    mock_http.expect(:request, Net::HTTPBadRequest.new("1.1", "400", "Bad Request").tap { |r|
      r.instance_variable_set(:@body, {
        "error" => { "message" => "Invalid parameter", "type" => "OAuthException", "code" => 100 }
      }.to_json)
      r.instance_variable_set(:@read, true)
    }, [Net::HTTP::Post])

    Net::HTTP.stub(:new, mock_http) do
      result = Reservi::Channels::InstagramAdapter.new.send_message(delivery: @delivery)
      assert_equal "failed", result[:status]
      assert_equal "Invalid parameter", result[:error]
    end
  end

  test "send_message returns failed on network error" do
    broken = ->(*args) { raise Net::OpenTimeout, "execution expired" }
    Net::HTTP.stub(:new, broken) do
      result = Reservi::Channels::InstagramAdapter.new.send_message(delivery: @delivery)
      assert_equal "failed", result[:status]
      assert_match(/execution expired/, result[:error])
    end
  end
end