require "application_system_test_case"

class FlowBuilderTest < ApplicationSystemTestCase
  setup do
    @account = accounts(:alpha)
    @alice = users(:alice)
    @flow_version = flow_versions(:alpha_v1)
    @flow_version.flow.update!(current_version: @flow_version)
  end

  # ── helpers ──────────────────────────────────────────────────────────

  def sign_in_and_enter
    sign_in_as(@alice, account: @account)
    assert_text @account.name
  end

  def navigate_to_flows
    click_on "Flows"
    assert_selector "h1", text: "Flows"
  end

  def create_flow_named(name)
    click_on "New flow"
    assert_selector "h1", text: "New flow"
    fill_in "Name", with: name
    click_button "Create flow"
    assert_text "Flow created"
  end

  # The Publish button_to is configured with data: { turbo: false } so it
  # submits as a plain POST form without Turbo confirm dialogs.
  def click_publish
    click_button "Publish"
  end

  # ── desktop ──────────────────────────────────────────────────────────

  test "full builder journey at desktop (1400x900)" do
    resize_desktop
    sign_in_and_enter
    navigate_to_flows

    # ── create flow ──────────────────────────────────────────────────
    create_flow_named("Builder Test Flow")
    assert_text "Builder Test Flow"
    assert_text "Stage 1"  # default stage created automatically
    assert_text "Status: Draft"

    # ── add a second stage with a field block ────────────────────────
    click_on "Add stage"
    assert_selector "h1", text: "Add stage"

    fill_in "Key", with: "qualification"
    fill_in "Label", with: "Qualification"
    fill_in "Position", with: "2"

    # Set block type to Field. The field-key input is in a div that is
    # display:none by default (toggled by JS). With rack_test we use
    # visible: :all to reach it.
    assert_selector "#blocks-container"
    find("select[name='blocks[0][type]']").find(:option, "Field").select_option
    find("input[name='blocks[0][key]']", visible: :all).set("budget")

    # Leave completion as the default literal-false (valid for publish)
    click_button "Add stage"
    assert_text "Stage added"
    assert_text "Qualification"

    # ── verify both stages appear in the version editor ──────────────
    assert_text "Stage 1"
    assert_text "Qualification"

    # ── preview the draft flow ───────────────────────────────────────
    click_button "Preview"
    assert_selector "h1", text: "Preview"
    assert_text "Draft preview"
    assert_text "Stage Evaluation"
    assert_text "Stage 1"
    assert_text "Qualification"

    # Should show blocks summary for the qualification stage
    assert_text "Field: budget"

    # ── return to editor ─────────────────────────────────────────────
    click_on "Back to editor"
    assert_text "Builder Test Flow"

    # ── publish ──────────────────────────────────────────────────────
    click_publish
    assert_text "Flow version published"
    assert_text "Published"
    assert_no_text "Draft" # status should now be "Published"

    # ── verify it shows as published on the flows index ──────────────
    click_on "Back"
    assert_text "Builder Test Flow"
    assert_text "Published v1"
  end

  # ── phone ────────────────────────────────────────────────────────────

  test "full builder journey at phone (375x812)" do
    resize_phone
    sign_in_and_enter
    navigate_to_flows

    # ── create flow ──────────────────────────────────────────────────
    create_flow_named("Phone Builder Test")
    assert_text "Phone Builder Test"
    assert_text "Stage 1"
    assert_text "Status: Draft"

    # ── add a second stage with a catalog block ──────────────────────
    click_on "Add stage"
    assert_selector "h1", text: "Add stage"

    fill_in "Key", with: "review"
    fill_in "Label", with: "Review"
    fill_in "Position", with: "2"

    # Set block type to Catalog and fill required catalog_key.
    # The catalog_key input is in a display:none div when no JS runs,
    # so use visible: :all.
    find("select[name='blocks[0][type]']").find(:option, "Catalog selector").select_option
    find("input[name='blocks[0][catalog_key]']", visible: :all).set("services")

    click_button "Add stage"
    assert_text "Stage added"
    assert_text "Review"

    # ── verify both stages appear ────────────────────────────────────
    assert_text "Stage 1"
    assert_text "Review"

    # ── preview ──────────────────────────────────────────────────────
    click_button "Preview"
    assert_selector "h1", text: "Preview"
    assert_text "Draft preview"
    assert_text "Stage Evaluation"
    assert_text "Review"

    # Should show the catalog block in the preview
    assert_text "Catalog: services"

    # ── back to editor and publish ───────────────────────────────────
    click_on "Back to editor"
    click_publish
    assert_text "Flow version published"
    assert_text "Published"

    # ── verify on index ──────────────────────────────────────────────
    click_on "Back"
    assert_text "Phone Builder Test"
    assert_text "Published"
  end

  # ── viewport helpers ─────────────────────────────────────────────────

  private

  def resize_desktop
    return unless Capybara.current_driver == :headless_chrome
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def resize_phone
    return unless Capybara.current_driver == :headless_chrome
    page.driver.browser.manage.window.resize_to(375, 812)
  end
end
