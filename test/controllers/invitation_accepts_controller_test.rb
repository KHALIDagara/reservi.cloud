require "test_helper"

class InvitationAcceptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = account_invitations(:alpha_dora_pending)
    @token = "test-invite-token-dora"
    sign_in_as(users(:dora))
  end

  test "show displays role and teams before acceptance" do
    get accept_invitation_url(token: @token)
    assert_response :success
    assert_match "operator", response.body
    assert_match "General", response.body
  end

  test "accept creates Membership, Agent and TeamMemberships" do
    post accept_invitation_url(token: @token)
    assert_response :redirect
    follow_redirect!
    assert_response :success

    membership = Membership.find_by(user_id: users(:dora).id, account_id: accounts(:alpha).id)
    assert membership.persisted?
    assert membership.active?
    assert_equal "operator", membership.role

    agent = membership.agent
    assert agent.present?
    assert_equal "human", agent.kind
    assert agent.active?

    tm = agent.team_memberships.active
    assert_equal 1, tm.count
    assert_equal teams(:alpha_general).id, tm.first.team_id
  end

  test "cannot accept revoked invitation" do
    revoked = account_invitations(:alpha_revoked)
    post accept_invitation_url(token: "test-invite-token-revoked")
    assert_response :redirect
    assert_match "revoked", flash[:alert]
  end

  test "cannot accept expired invitation" do
    expired = account_invitations(:alpha_expired)
    post accept_invitation_url(token: "test-invite-token-expired")
    assert_response :redirect
    assert_match "expired", flash[:alert]
  end

  test "wrong token fails" do
    post accept_invitation_url(token: "wrong-token")
    assert_response :redirect
    assert_match "invalid", flash[:alert]
  end
end