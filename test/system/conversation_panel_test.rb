require "application_system_test_case"

class ConversationPanelTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
    @alice = users(:alice)
    @conversation = conversations(:alpha_active)
    # Ensure the conversation has a stage with some blocks for testing
    @stage = @conversation.current_stage
  end

  test "conversation page renders with panel toggle on mobile" do
    resize_phone
    sign_in_as(@alice, account: @account)
    visit account_conversation_url(account_id: @account.id, id: @conversation.id)

    # Should see the conversation
    assert_selector "h1", text: @conversation.customer.name

    # Panel toggle button visible on mobile
    assert_button "Tools"

    # Messages area visible
    assert_selector "[data-controller='slide-panel']"
  end

  test "conversation page renders with panel visible on desktop" do
    resize_desktop
    sign_in_as(@alice, account: @account)
    visit account_conversation_url(account_id: @account.id, id: @conversation.id)

    assert_selector "h1", text: @conversation.customer.name

    # Turbo frame for panel is present (may show "Loading tools..." since it's lazy)
    assert_selector "turbo-frame#conversation_panel"
  end

  test "panel endpoint returns content" do
    sign_in_as(@alice, account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    # Panel should show stage info
    assert_text @stage.label
    assert_text "Assignment"

    # Should show available agents
    assert_text "Alice Admin"
  end

  test "can send message and add note" do
    sign_in_as(@alice, account: @account)
    visit account_conversation_url(account_id: @account.id, id: @conversation.id)

    # Reply form
    fill_in "content", with: "Hello from panel test", match: :first
    click_button "Send", match: :first
    assert_text "Hello from panel test"

    # Note form
    within("form[action*='notes']") do
      fill_in "content", with: "Test note"
      click_button "Add note"
    end
    assert_text "Test note"
  end
end
