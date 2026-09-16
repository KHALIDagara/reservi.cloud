require "test_helper"

class Accounts::InboxControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
    @account = accounts(:alpha)
    @flow = flows(:alpha_default)
    @flow_version = flow_versions(:alpha_v1)
    @flow.update!(current_version: @flow_version)
  end

  test "inbox index renders" do
    get account_inbox_url(@account)
    assert_response :success
    assert_select "h1", text: "Inbox"
  end

  test "inbox shows filter tabs" do
    get account_inbox_url(@account)
    assert_select "a[href='#{account_inbox_path(@account)}']", text: "All"
    assert_select "a[href='#{account_inbox_path(@account, filter: 'mine')}']", text: "Mine"
    assert_select "a[href='#{account_inbox_path(@account, filter: 'unowned')}']", text: "Unowned"
  end

  test "inbox filters by mine" do
    alice = agents(:alpha_alice_human)
    bob = agents(:alpha_bob_human)

    # Create conversations owned by alice and bob
    alice_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Alice Customer" },
      agent: alice,
      content: "Hello"
    )
    bob_conv = Conversations::Create.call(
      account: @account,
      customer_attributes: { name: "Bob Customer" },
      agent: bob,
      content: "Hi"
    )
    bob_conv.update!(owner: bob)
    alice_conv.update!(owner: alice)

    # Sign in as bob and filter by mine
    sign_out
    sign_in_as(users(:bob))
    get account_inbox_url(@account, filter: "mine")
    assert_response :success
    assert_select "a[href='#{account_conversation_path(@account, bob_conv)}']"
  end

  test "inbox does not show conversations from another account" do
    get account_inbox_url(accounts(:beta))
    assert_response :success
  end

  test "unauthenticated user is redirected" do
    sign_out
    get account_inbox_url(@account)
    assert_redirected_to new_session_path
  end
end
