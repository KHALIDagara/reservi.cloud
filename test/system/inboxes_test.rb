require "application_system_test_case"

class InboxesTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    sign_in_as users(:alice), account: @account
  end

  test "admin chooses an inbox provider and reaches its connection step" do
    resize_phone
    visit account_channels_url(@account)

    assert_text "Inboxes"
    click_link "Connect inbox"
    assert_text "Where do customers message you?"

    click_link "WhatsApp"
    assert_text "Connect with WhatsApp"
    assert_text "Meta application credentials"

    visit new_account_channel_url(@account)
    click_link "Instagram"
    assert_text "Connect with Instagram"
    assert_text "Meta application credentials"
  end
end
