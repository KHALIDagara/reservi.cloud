require "application_system_test_case"

class ConversationPanelTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
    @alice = users(:alice)
    @conversation = conversations(:alpha_active)
    @stage = @conversation.current_stage
    @account.field_definitions.create!(scope: "conversation", key: "budget", label: "Budget", field_type: "number", position: 1)
    @stage.update!(blocks: [ { "type" => "field", "key" => "budget" } ])
  end

  test "conversation page renders with panel toggle on mobile" do
    resize_phone
    sign_in_as(@alice, account: @account)
    visit account_conversation_url(account_id: @account.id, id: @conversation.id)

    # Should see the conversation
    assert_selector "h1", text: @conversation.customer.name

    assert_button "Work"
    assert_selector "[data-controller='slide-panel']"

    if javascript_driver?
      click_button "Work"
      assert_selector "#conversation-work-panel[role='dialog'][aria-hidden='false']"
      assert_text(/assignment/i)
      assert_equal false, page.evaluate_script("document.querySelector('#conversation-work-panel').inert")

      find("[data-slide-panel-target='closeButton']").click
      assert_selector "#conversation-work-panel[aria-hidden='true']", visible: :all
      assert_equal true, page.evaluate_script("document.querySelector('#conversation-work-panel').inert")
    end
  end

  test "conversation page renders with panel visible on desktop" do
    resize_desktop
    sign_in_as(@alice, account: @account)
    visit account_conversation_url(account_id: @account.id, id: @conversation.id)

    assert_selector "h1", text: @conversation.customer.name

    assert_selector "turbo-frame#conversation_panel"
    if javascript_driver?
      assert_selector "#conversation-work-panel[role='complementary']"
      assert_text(/assignment/i)
    end
  end

  test "panel endpoint returns content" do
    sign_in_as(@alice, account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    # Panel should show stage info
    assert_text @stage.label
    assert_text "Assignment"

    # Should show available agents
    assert_text "Alice Admin"
    assert_selector "turbo-frame#conversation_panel"
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
