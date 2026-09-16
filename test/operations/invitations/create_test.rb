require "test_helper"

class Invitations::CreateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @actor = memberships(:alpha_alice)
    @team = teams(:alpha_general)
  end

  test "creates pending invitation and enqueues delivery job" do
    invitations = Invitations::Create.call(
      account: @account,
      actor_membership: @actor,
      emails: [ "new@example.com" ],
      role: "operator",
      team_ids: [ @team.id ]
    )

    assert_equal 1, invitations.length
    invitation = invitations.first
    assert invitation.persisted?
    assert_equal "new@example.com", invitation.email
    assert_equal "pending", invitation.status
    assert invitation.token_digest.present?
    assert invitation.expires_at > Time.current
    assert_enqueued_with(job: Invitations::DeliverJob, args: [ invitation ])
  end

  test "multiple emails create multiple invitations" do
    invitations = Invitations::Create.call(
      account: @account,
      actor_membership: @actor,
      emails: [ "a@example.com, b@example.com", "c@example.com" ],
      role: "manager",
      team_ids: [ @team.id ]
    )

    assert_equal 3, invitations.length
    assert_equal %w[a@example.com b@example.com c@example.com].sort, invitations.map(&:email).sort
  end

  test "existing active member raises" do
    e = assert_raises(Reservi::Errors::OperationError) do
      Invitations::Create.call(
        account: @account,
        actor_membership: @actor,
        emails: [ users(:bob).email_address ],
        role: "operator",
        team_ids: [ @team.id ]
      )
    end
    assert_match /already an active member/, e.message
  end

  test "already pending email raises" do
    Invitations::Create.call(
      account: @account,
      actor_membership: @actor,
      emails: [ "pending@example.com" ],
      role: "operator",
      team_ids: [ @team.id ]
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Invitations::Create.call(
        account: @account,
        actor_membership: @actor,
        emails: [ "pending@example.com" ],
        role: "operator",
        team_ids: [ @team.id ]
      )
    end
    assert_match /already has a pending invitation/, e.message
  end

  test "non-admin actor raises AuthorizationError" do
    bob = memberships(:alpha_bob)
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Invitations::Create.call(
        account: @account,
        actor_membership: bob,
        emails: [ "new@example.com" ],
        role: "operator",
        team_ids: [ @team.id ]
      )
    end
    assert_match /Only an Account administrator/, e.message
  end

  test "invalid team raises" do
    e = assert_raises(Reservi::Errors::OperationError) do
      Invitations::Create.call(
        account: @account,
        actor_membership: @actor,
        emails: [ "new@example.com" ],
        role: "operator",
        team_ids: [ 99999 ]
      )
    end
    assert_match /no longer exist/, e.message
  end
end
