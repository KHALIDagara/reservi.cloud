require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
    @alice = users(:alice)
  end

  test "create conversation, reply, add note, and refresh" do
    # Sign in using the helper (works with both rack_test and headless_chrome)
    sign_in_as(@alice, account: @account)
    visit account_inbox_url(account_id: @account.id)

    # Should see the inbox
    assert_selector "h1", text: "Inbox"

    # Click New conversation
    click_on "New conversation"
    assert_selector "h1", text: "New conversation"

    # Fill in customer + initial message
    fill_in "Customer name", with: "System Test Customer"
    fill_in "Email address", with: "system@example.com"
    fill_in "Initial message", with: "I need help with a garden service."

    click_button "Create conversation"

    # Should land on the conversation detail page
    assert_selector "h1", text: "System Test Customer"
    assert_text "I need help with a garden service."

    # Reply to the customer (first textarea is the message form)
    within("form[action*='messages']") do
      fill_in "content", with: "Thank you for reaching out! How can I help?"
      click_button "Send"
    end

    # Should see the reply
    assert_text "Thank you for reaching out!"

    # Add an internal note (textarea in the notes form)
    within("form[action*='notes']") do
      fill_in "content", with: "Customer seems interested in monthly maintenance."
      click_button "Add note"
    end

    # Should see the note
    assert_text "Customer seems interested in monthly maintenance."

    # Go back to inbox
    click_on "Back to inbox"

    # Verify the conversation appears in the inbox
    assert_selector "h1", text: "Inbox"
    assert_text "System Test Customer"
  end
end