require "application_system_test_case"

class LandingPageTest < ApplicationSystemTestCase
  setup do
    @alice = users(:alice)
  end

  test "logged-out visitor sees landing page with sign-in and sign-up CTAs" do
    visit root_url

    # Hero section
    assert_selector "h1", text: /conversation.*completed/i
    assert_link "Start free"
    assert_link "Sign in"

    # Value props section
    assert_text "Your inbox is your process"
    assert_text "Inbox-first"
    assert_text "Configurable stages"
    assert_text "Deterministic automation"

    # How it works
    assert_text "How it works"
    assert_text "Configure your flow"
    assert_text "Inbox does the work"
    assert_text "Stages complete themselves"

    # For who
    assert_text "Service businesses"
    assert_text "Rental"
    assert_text "Clinics"
    assert_text "Agencies"

    # Bottom CTA
    assert_text "Move from conversations to completed work"

    # Footer
    assert_text(/Reservi/)
  end

  test "sign-up CTA links to registration page" do
    visit root_url
    click_on "Start free", match: :first
    assert_current_path register_path
  end

  test "sign-in CTA links to session page" do
    visit root_url
    click_on "Sign in", match: :first
    assert_current_path new_session_path
  end

  test "signed-in user visiting root is redirected to accounts" do
    sign_in_as(@alice)
    assert_current_path accounts_path
    assert_selector "h1", text: "Your accounts"
  end

  test "landing page renders correctly at phone size" do
    resize_phone
    visit root_url
    assert_selector "h1", text: /conversation.*completed/i
    assert_link "Start free"
    assert_link "Sign in"
  end
end