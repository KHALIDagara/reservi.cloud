require "application_system_test_case"

class MobileCoreJourneysTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
    @alice = users(:alice)
  end

  test "phone inbox renders filter tabs" do
    resize_phone
    sign_in_as(@alice, account: @account)
    visit account_inbox_url(account_id: @account.id)
    assert_selector "h1", text: "Inbox"
    assert_text "All"
    assert_text "Mine"
    assert_text "Unowned"
  end

  test "desktop inbox renders filter tabs" do
    resize_desktop
    sign_in_as(@alice, account: @account)
    visit account_inbox_url(account_id: @account.id)
    assert_selector "h1", text: "Inbox"
    assert_text "All"
    assert_text "Mine"
    assert_text "Unowned"
  end

  test "conversation page renders at phone size" do
    resize_phone
    sign_in_as(@alice, account: @account)
    conv = conversations(:alpha_active)
    visit account_conversation_url(account_id: @account.id, id: conv.id)
    assert_selector "h1", text: conv.customer.name
    assert_text(/message/i)   # reply form area
    assert_text(/note/i)      # note form area
  end

  test "refresh preserves conversation state" do
    sign_in_as(@alice, account: @account)
    conv = conversations(:alpha_active)
    visit account_conversation_url(account_id: @account.id, id: conv.id)
    assert_selector "h1", text: conv.customer.name
    # Refresh the page
    visit current_url
    assert_selector "h1", text: conv.customer.name
  end

  test "new conversation form renders" do
    sign_in_as(@alice, account: @account)
    visit new_account_conversation_url(account_id: @account.id)
    assert_selector "h1", text: "New conversation"
    assert_field "Customer name"
    assert_field "Initial message"
    assert_button "Create conversation"
  end
end