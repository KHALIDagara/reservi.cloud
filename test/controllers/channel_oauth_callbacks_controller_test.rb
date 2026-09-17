require "test_helper"
require "minitest/mock"

class ChannelOauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    sign_in_as(users(:alice))
  end

  test "Instagram OAuth round trip creates an inbox and consumes state" do
    fake_client = Object.new
    fake_client.define_singleton_method(:authorization_url) do |redirect_uri:, state:|
      "https://instagram.example/oauth?#{URI.encode_www_form(redirect_uri:, state:)}"
    end
    fake_client.define_singleton_method(:connect_instagram) do |code:, redirect_uri:|
      {
        provider: "instagram", external_id: "1784140001", name: "reservi",
        provider_config: { "instagram_id" => "1784140001", "username" => "reservi" },
        credentials: { "access_token" => "instagram-secret", "webhook_verify_token" => "verify" }
      }
    end

    Reservi::Channels::OauthClient.stub(:new, fake_client) do
      get authorize_account_channel_url(@account, provider: "instagram")
    end
    assert_response :redirect
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

    assert_difference -> { @account.channels.count } => 1 do
      Reservi::Channels::OauthClient.stub(:new, fake_client) do
        get channel_oauth_callback_url(provider: "instagram", state:, code: "oauth-code")
      end
    end

    channel = @account.channels.last
    assert_redirected_to account_channel_path(@account, channel)
    assert_equal "instagram", channel.provider_type
    assert_equal "instagram-secret", channel.credential("access_token")

    assert_no_difference -> { @account.channels.count } do
      get channel_oauth_callback_url(provider: "instagram", state:, code: "replay")
    end
    assert_redirected_to accounts_path
    assert_match(/expired or is invalid/, flash[:alert])
  end

  test "state cannot be used by another user" do
    fake_client = Object.new
    fake_client.define_singleton_method(:authorization_url) do |redirect_uri:, state:|
      "https://instagram.example/oauth?#{URI.encode_www_form(redirect_uri:, state:)}"
    end
    Reservi::Channels::OauthClient.stub(:new, fake_client) do
      get authorize_account_channel_url(@account, provider: "instagram")
    end
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

    sign_out
    sign_in_as(users(:bob))
    get channel_oauth_callback_url(provider: "instagram", state:, code: "oauth-code")

    assert_redirected_to accounts_path
    assert_match(/expired or is invalid/, flash[:alert])
  end
end
