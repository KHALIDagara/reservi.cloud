require "test_helper"
require "minitest/mock"

class Reservi::Channels::OauthClientTest < ActiveSupport::TestCase
  test "Instagram connection exchanges the token, reads identity, and subscribes webhooks" do
    with_env("INSTAGRAM_APP_ID" => "app-id", "INSTAGRAM_APP_SECRET" => "app-secret") do
      client = Reservi::Channels::OauthClient.new("instagram")
      calls = []
      responses = [
        { "access_token" => "short-token" },
        { "access_token" => "long-token", "expires_in" => 3600 },
        { "id" => "ig-id", "username" => "reservi", "account_type" => "BUSINESS" },
        { "success" => true }
      ]
      requester = lambda do |method, url, **options|
        calls << [ method, url, options ]
        responses.shift
      end

      connection = client.stub(:request_json, requester) do
        client.connect_instagram(code: "code", redirect_uri: "https://example.test/callback")
      end

      assert_equal "ig-id", connection[:external_id]
      assert_equal "long-token", connection.dig(:credentials, "access_token")
      assert_equal :post, calls.last.first
      assert_includes calls.last.second, "/ig-id/subscribed_apps"
      assert_includes calls.last.dig(2, :form, :subscribed_fields), "messages"
    end
  end

  test "WhatsApp connection authenticates, validates phone, and returns connection hash" do
    with_env(
      "WHATSAPP_APP_ID" => "app-id",
      "WHATSAPP_APP_SECRET" => "app-secret",
      "WHATSAPP_CONFIGURATION_ID" => "config-id"
    ) do
      client = Reservi::Channels::OauthClient.new("whatsapp")
      calls = []
      responses = [
        { "access_token" => "access-token" },
        { "data" => [ { "id" => "phone-id", "display_phone_number" => "+212600000000", "verified_name" => "Reservi" } ] }
      ]
      requester = lambda do |method, url, **options|
        calls << [ method, url, options ]
        responses.shift
      end

      connection = client.stub(:request_json, requester) do
        client.connect_whatsapp(code: "code", business_id: "business-id", waba_id: "waba-id", phone_number_id: "phone-id")
      end

      assert_equal "phone-id", connection[:external_id]
      assert_equal "access-token", connection.dig(:credentials, "access_token")
      assert_equal "Reservi", connection.dig(:provider_config, "verified_name")
      assert connection.dig(:provider_config, "webhook_verify_token").present?, "must have verify token"
      assert connection.dig(:provider_config, "display_phone_number").present?, "must have display phone"

      # connect_whatsapp only authenticates and returns a hash — no Meta API calls.
      # Phase 1 (auth): access token exchange + phone lookup (2 calls)
      assert_equal 2, calls.size
      assert_includes calls[0].second, "/oauth/access_token"
      assert_includes calls[1].second, "/waba-id/phone_numbers"
    end
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
