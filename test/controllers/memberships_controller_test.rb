require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
    @bob = memberships(:alpha_bob)

    # Debug output
    puts "DEBUG: account.id = #{@account.id}"
    puts "DEBUG: bob.id = #{@bob.id}"
    puts "DEBUG: remove_url = #{account_membership_remove_url(@account, @bob)}"
  end

  test "update role promotes operator to manager" do
    post account_membership_role_path(@account, @bob), params: { membership: { role: "manager" } }
    assert_response :redirect

    @bob.reload
    assert_equal "manager", @bob.role
  end

  test "demote last admin fails" do
    post account_membership_role_path(@account, memberships(:alpha_alice)), params: { membership: { role: "operator" } }
    assert_response :redirect
    assert_match /At least one active administrator/, flash[:alert]
  end

  test "remove deactivates membership and agent" do
    post account_membership_remove_path(@account, @bob)
    assert_response :redirect

    @bob.reload
    assert_not @bob.active?
    assert_not @bob.agent.active?
  end

  test "cannot self-remove when last admin" do
    post account_membership_remove_path(@account, memberships(:alpha_alice))
    assert_response :redirect
    assert_match /At least one active administrator/, flash[:alert]
  end

  test "operator cannot remove" do
    sign_in_as(users(:bob))

    post account_membership_remove_path(@account, memberships(:alpha_alice))
    assert_response :redirect
    assert_match /Only Account administrators can manage members/, flash[:alert]
  end
end
