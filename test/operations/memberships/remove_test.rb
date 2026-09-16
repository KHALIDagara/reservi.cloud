require "test_helper"

class Memberships::RemoveTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
    @bob = memberships(:alpha_bob)
  end

  test "admin can deactivate another member" do
    Memberships::Remove.call(membership: @bob, actor_membership: @admin)
    @bob.reload
    assert_not @bob.active?
    assert_not @bob.agent.active?
  end

  test "admin can self-remove if another admin exists" do
    carol = users(:carol)
    puts "DEBUG: Carol user ID: #{carol.id}"
    puts "DEBUG: Alpha account ID: #{@account.id}"

    extra_admin = @account.memberships.create!(user: carol, role: "admin", active: true)
    puts "DEBUG: Created extra_admin: #{extra_admin.id}"

    # Verify it's visible
    other_admins = @account.memberships.active.admins.where.not(id: @admin.id)
    puts "DEBUG: Other active admins before remove: #{other_admins.count}"
    other_admins.each { |m| puts "  - #{m.id} user=#{m.user.email_address}" }

    Memberships::Remove.call(membership: @admin, actor_membership: @admin)
    @admin.reload
    assert_not @admin.active?
  ensure
    extra_admin&.destroy
  end

  test "self-remove fails when last admin" do
    e = assert_raises(Reservi::Errors::OperationError) do
      Memberships::Remove.call(membership: @admin, actor_membership: @admin)
    end
    assert_match /At least one active administrator/, e.message
  end

  test "demoting last admin fails" do
    e = assert_raises(Reservi::Errors::OperationError) do
      Memberships::ChangeRole.call(membership: @admin, role: "operator", actor_membership: @admin)
    end
    assert_match /At least one active administrator/, e.message
  end

  test "operator cannot remove anyone" do
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Memberships::Remove.call(membership: @bob, actor_membership: @bob)
    end
    assert_match /Only an Account administrator/, e.message
  end

  test "removed member can accept new invitation and gets the invited role" do
    Memberships::Remove.call(membership: @bob, actor_membership: @admin)

    invitation = @account.account_invitations.create!(
      email: @bob.user.email_address,
      role: "admin",
      team_ids: [ teams(:alpha_general).id ],
      inviter_membership: @admin,
      token_digest: Digest::SHA256.hexdigest("new-token"),
      expires_at: 7.days.from_now,
      status: "pending",
      delivery_status: "pending"
    )

    # Gets the admin role from the new invitation, not the old operator role
    Invitations::Accept.call(invitation: invitation, token: "new-token", user: @bob.user)
    membership = @account.memberships.find_by(user: @bob.user)
    assert membership.active?
    assert_equal "admin", membership.role
  end
end
