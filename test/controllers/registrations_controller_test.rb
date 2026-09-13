require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new registration renders" do
    get register_url
    assert_response :success
    assert_select "form[action='/register']"
  end

  test "create registers user, enqueues verification email, and starts session" do
    post register_url, params: { user: { name: "New User", email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }

    assert_response :redirect
    # Session cookie should be set
    assert cookies[:session_id].present?

    # User should be persisted in DB
    user = User.find_by(email_address: "new@example.com")
    assert user.persisted?
    assert_not user.verified?
    assert user.verification_token_digest.present?

    # Follow redirect and verify we land at accounts (authenticated)
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Your accounts"

    # Verify verification email was enqueued
    assert_enqueued_jobs 1, only: Users::DeliverVerificationJob
  end

  test "validation failures render new with errors" do
    post register_url, params: { user: { name: "", email_address: "bad", password: "short", password_confirmation: "different" } }
    assert_response :unprocessable_content
    assert_select ".text-red-600"
  end
end