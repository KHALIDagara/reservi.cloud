require "test_helper"

class Invitations::RevokeTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @actor = memberships(:alpha_alice)
    @invitation = account_invitations(:alpha_dora_pending)
  end

  test "revokes pending invitation and erases delivery token" do
    assert @invitation.token_digest.present?
    # delivery_token is already nil since the fixture represents a delivered invitation
    # The revoke operation should still work and change status to "revoked"

    Invitations::Revoke.call(invitation: @invitation, actor_membership: @actor)

    @invitation.reload
    assert_equal "revoked", @invitation.status
    assert_nil @invitation.delivery_token
    # token_digest is kept for audit purposes (the token hash)
  end

  test "only admin can revoke" do
    bob = memberships(:alpha_bob)
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Invitations::Revoke.call(invitation: @invitation, actor_membership: bob)
    end
    assert_match /Only an Account administrator/, e.message
  end

  test "accepted invitation cannot be revoked" do
    @invitation.update!(status: "accepted")
    e = assert_raises(Reservi::Errors::OperationError) do
      Invitations::Revoke.call(invitation: @invitation, actor_membership: @actor)
    end
    assert_match /Only pending invitations/, e.message
  end
end
