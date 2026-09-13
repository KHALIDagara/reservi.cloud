require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
  end

  test "create sends invitations and enqueues delivery jobs" do
    assert_enqueued_jobs 2, only: Invitations::DeliverJob do
      post account_invitations_url(@account),
           params: { invitation: { emails: "a@example.com, b@example.com", role: "operator", team_ids: [teams(:alpha_general).id] } }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_equal 2, @account.account_invitations.pending.where(email: ["a@example.com", "b@example.com"]).count
  end

  test "resend rotates token and re-enqueues" do
    invitation = account_invitations(:alpha_dora_pending)
    old_digest = invitation.token_digest

    post resend_account_invitation_url(@account, invitation)
    assert_response :redirect

    invitation.reload
    assert_not_equal old_digest, invitation.token_digest
    assert_equal "pending", invitation.delivery_status
    assert_equal 0, invitation.delivery_attempts
    assert_enqueued_with(job: Invitations::DeliverJob)
  end

  test "revoke revokes and erases delivery token" do
    invitation = account_invitations(:alpha_dora_pending)

    post revoke_account_invitation_url(@account, invitation)
    assert_response :redirect

    invitation.reload
    assert_equal "revoked", invitation.status
    assert_nil invitation.delivery_token
    # token_digest is kept for audit purposes
  end

  test "operator cannot create invitations" do
    sign_in_as(users(:bob))

    post account_invitations_url(@account), params: { invitation: { emails: "x@example.com", role: "operator", team_ids: [teams(:alpha_general).id] } }
    assert_response :redirect
    assert_match "Only Account administrators can manage invitations", flash[:alert]
  end
end