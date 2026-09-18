require "test_helper"
require "minitest/mock"

class Accounts::ChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    sign_in_as(users(:alice))
  end

  test "admin sees inboxes and provider picker" do
    get inboxes_url(@account)
    assert_response :success
    assert_select "h1", text: "Inboxes"
    assert_select "a[href='#{new_account_inbox_connect_path(@account)}']", text: /Connect/

    get new_account_inbox_connect_url(@account)
    assert_response :success
    assert_select "a[href='#{setup_account_inbox_path(@account, provider: 'whatsapp')}']", text: /WhatsApp/
    assert_select "a[href='#{setup_account_inbox_path(@account, provider: 'instagram')}']", text: /Instagram/
  end

test "operator can see inboxes but cannot manage them" do
    sign_out
    sign_in_as(users(:bob))

    get inboxes_url(@account)
    assert_response :success  # anyone can view inboxes

    get new_account_inbox_connect_url(@account)
    assert_redirected_to accounts_url  # but connect requires admin
    assert_equal "Only Account administrators can manage inboxes.", flash[:alert]
  end

  test "unknown provider setup is not routable" do
    get setup_account_inbox_url(@account, provider: "unknown")
    assert_response :not_found
  end

  test "WhatsApp completion creates an encrypted connected inbox" do
    fake_client = Object.new
    connection = {
      provider: "whatsapp",
      external_id: "12345",
      name: "Reservi Support",
      provider_config: { "phone_number_id" => "12345", "display_phone_number" => "+212600000000" },
      credentials: { "access_token" => "secret-token", "webhook_verify_token" => "verify-token" }
    }
    fake_client.define_singleton_method(:connect_whatsapp) { |**| connection }

    assert_difference -> { @account.channels.count } => 1 do
      Reservi::Channels::OauthClient.stub(:new, fake_client) do
        post complete_whatsapp_account_inbox_url(@account), params: {
          code: "oauth-code", business_id: "11", waba_id: "22", phone_number_id: "12345"
        }, as: :json
      end
    end

    assert_response :created
    channel = @account.channels.last
    assert_equal "secret-token", channel.credential("access_token")
    assert_not_includes channel.read_attribute_before_type_cast("credentials"), "secret-token"
    assert_equal inbox_path(@account, channel), response.parsed_body["redirect_url"]
  end

  test "WhatsApp completion rejects missing embedded signup identity" do
    assert_no_difference -> { @account.channels.count } do
      post complete_whatsapp_account_inbox_url(@account), params: {
        code: "oauth-code", business_id: "11", waba_id: "22"
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_match(/incomplete signup details/, response.parsed_body["error"])
  end
end
