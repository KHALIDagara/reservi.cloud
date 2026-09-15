require "test_helper"

class Accounts::FlowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @admin = users(:alice)
    @operator = users(:bob)
  end

  test "index renders for admin" do
    sign_in_as(@admin)
    get flows_url(account_id: @account.id)
    assert_response :success
    assert_select "h1"
  end

  test "index requires authentication" do
    get flows_url(account_id: @account.id)
    assert_redirected_to new_session_path
  end

  test "index requires admin" do
    sign_in_as(@operator)
    get flows_url(account_id: @account.id)
    assert_redirected_to accounts_path
  end

  test "new renders form" do
    sign_in_as(@admin)
    get new_flow_url(account_id: @account.id)
    assert_response :success
    assert_select "form"
  end

  test "create flow with initial stage" do
    sign_in_as(@admin)
    assert_difference -> { @account.flows.count } => 1 do
      post flows_url(account_id: @account.id), params: { flow: { name: "Test Flow" } }
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success

    flow = @account.flows.find_by(name: "Test Flow")
    assert flow
    assert_equal 1, flow.versions.count
    version = flow.versions.first
    assert_equal "draft", version.status
    assert_equal 1, version.stages.count
  end

  test "edit shows flow with versions" do
    sign_in_as(@admin)
    flow = @account.flows.first
    get edit_flow_url(account_id: @account.id, id: flow)
    assert_response :success
    assert_select "h1"
  end

  test "update flow name" do
    sign_in_as(@admin)
    flow = @account.flows.first
    patch flow_url(account_id: @account.id, id: flow), params: { flow: { name: "Updated" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "Updated", flow.reload.name
  end

  test "non-admin cannot create flow" do
    sign_in_as(@operator)
    assert_no_difference -> { @account.flows.count } do
      post flows_url(account_id: @account.id), params: { flow: { name: "Test" } }
    end
    assert_redirected_to accounts_path
  end
end