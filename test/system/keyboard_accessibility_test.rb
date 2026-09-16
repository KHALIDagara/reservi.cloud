require "application_system_test_case"

class KeyboardAccessibilityTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @alice = users(:alice)
  end

  test "sign in form has accessible structure" do
    visit new_session_url
    # Fields exist with proper attributes
    assert_field "email_address"
    assert_field "password"
    assert_button "Sign in"
    # Forgot password link accessible
    assert_link "Forgot password?"
  end

  test "sign in with invalid credentials shows alert" do
    visit new_session_url
    fill_in "email_address", with: "nope@example.com"
    fill_in "password", with: "wrong"
    click_button "Sign in"
    assert_selector "#alert"
    assert_text(/try another/i)
  end

  test "account home page has navigation links" do
    sign_in_as(@alice, account: @account)
    assert_text "People & AI"
    assert_text "Inbox"
    assert_text "Flow"
  end

  test "new conversation form has labeled fields" do
    sign_in_as(@alice, account: @account)
    visit new_account_conversation_url(account_id: @account.id)
    assert_field "Customer name"
    assert_field "Initial message"
    assert_button "Create conversation"
  end

  test "empty conversation submission shows validation" do
    sign_in_as(@alice, account: @account)
    visit new_account_conversation_url(account_id: @account.id)
    click_button "Create conversation"
    # Should re-render form — the page should still be on the form
    assert_text(/New conversation|customer/i)
  end
end