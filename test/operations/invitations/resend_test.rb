require "test_helper"

class Invitations::ResendTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @actor = memberships(:alpha_alice)
    @invitation = account_invitations(:alpha_dora_pending)
  end

  test "rotates token, resets delivery state and re-enqueues delivery job" do
    old_digest = @invitation.token_digest

    Invitations::Resend.call(invitation: @invitation, actor_membership: @actor)

    @invitation.reload
    assert_not_equal old_digest, @invitation.token_digest
    assert_equal "pending", @invitation.delivery_status
    assert_equal 0, @invitation.delivery_attempts
    assert_enqueued_with(job: Invitations::DeliverJob)
  end

  test "only admin can resend" do
    bob = memberships(:alpha_bob)
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Invitations::Resend.call(invitation: @invitation, actor_membership: bob)
    end
    assert_match /Only an Account administrator/, e.message
  end

  test "accepted invitation cannot be resent" do
    @invitation.update!(status: "accepted")
    e = assert_raises(Reservi::Errors::OperationError) do
      Invitations::Resend.call(invitation: @invitation, actor_membership: @actor)
    end
    assert_match /Only pending invitations/, e.message
  end
end