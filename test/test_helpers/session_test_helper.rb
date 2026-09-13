module SessionTestHelper
  def sign_in_as(user)
    # Use the actual controller's start_new_session_for method
    post session_url, params: { email_address: user.email_address, password: "password123" }
    follow_redirect! if response.redirect?
    # Verify we're signed in
    assert cookies[:session_id].present?
  end

  def sign_out
    delete session_url
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end