require "test_helper"

class Memberships::ChangeRoleTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
    @bob = memberships(:alpha_bob)
  end

  test "admin can promote operator to manager" do
    Memberships::ChangeRole.call(membership: @bob, role: "manager", actor_membership: @admin)
    @bob.reload
    assert_equal "manager", @bob.role
  end

  test "admin can demote operator to admin if another admin exists" do
    carol = users(:carol)
    extra_admin = @account.memberships.create!(user: carol, role: "admin", active: true)

    Memberships::ChangeRole.call(membership: @admin, role: "operator", actor_membership: @admin)
    @admin.reload
    assert_equal "operator", @admin.role
  ensure
    extra_admin&.destroy
  end

  test "cannot demote last admin" do
    e = assert_raises(Reservi::Errors::OperationError) do
      Memberships::ChangeRole.call(membership: @admin, role: "operator", actor_membership: @admin)
    end
    assert_match /At least one active administrator/, e.message
  end

  test "operator cannot change roles" do
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Memberships::ChangeRole.call(membership: @bob, role: "manager", actor_membership: @bob)
    end
    assert_match /Only an Account administrator/, e.message
  end
end
