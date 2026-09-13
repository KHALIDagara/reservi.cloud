require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  test "valid token verifies and redirects" do
    user = users(:dora)
    token = user.set_verification_token!

    get verify_email_url(token: token)
    assert_response :redirect
    follow_redirect!
    assert_response :success

    user.reload
    assert user.verified?
    assert_nil user.verification_token_digest
  end

  test "invalid token redirects with alert" do
    get verify_email_url(token: "bad-token")
    assert_response :redirect
    follow_redirect!
    assert_match "invalid", flash[:alert]
  end

  test "already verified user cannot re-verify" do
    user = users(:alice)
    assert user.verified?

    get verify_email_url(token: "anything")
    assert_response :redirect
  end
end