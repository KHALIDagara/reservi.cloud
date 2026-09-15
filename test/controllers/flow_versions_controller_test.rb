require "test_helper"

class Accounts::FlowVersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @admin = users(:alice)
    @operator = users(:bob)
    @flow = @account.flows.first
  end

  test "new version renders form" do
    sign_in_as(@admin)
    get new_flow_flow_version_url(account_id: @account.id, flow_id: @flow)
    assert_response :success
    assert_select "form"
  end

  test "create draft version" do
    sign_in_as(@admin)
    assert_difference -> { @flow.versions.count } => 1 do
      post flow_flow_version_index_url(account_id: @account.id, flow_id: @flow),
        params: { flow_version: { version_number: 10 } }
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success

    version = @flow.versions.find_by(version_number: 10)
    assert version
    assert_equal "draft", version.status
    # Should have cloned stages from current published version
    assert version.stages.any?
  end

  test "create draft version without published parent creates default stage" do
    sign_in_as(@admin)
    flow = @account.flows.create!(name: "Empty Flow")
    post flow_flow_version_index_url(account_id: @account.id, flow_id: flow),
      params: { flow_version: { version_number: 1 } }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    version = flow.versions.first
    assert_equal 1, version.stages.count
  end

  test "edit version shows stage list" do
    sign_in_as(@admin)
    version = @flow.versions.first
    get edit_flow_flow_version_url(account_id: @account.id, flow_id: @flow, id: version)
    assert_response :success
  end

  test "publish version succeeds" do
    sign_in_as(@admin)
    draft = @flow.versions.create!(version_number: 99, status: "draft")
    draft.stages.create!(
      key: "stage_1", label: "Stage 1", position: 1,
      blocks: [], rules: [],
      completion: { "literal" => true }
    )
    post publish_flow_flow_version_url(account_id: @account.id, flow_id: @flow, id: draft)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert draft.reload.published?
    assert_equal draft.id, @flow.reload.current_version_id
  end

  test "publish already published version shows error" do
    sign_in_as(@admin)
    published = @flow.versions.first
    post publish_flow_flow_version_url(account_id: @account.id, flow_id: @flow, id: published)
    assert_response :redirect
    follow_redirect!
    assert_match /already published/i, response.body
  end

  test "publish empty version shows error" do
    sign_in_as(@admin)
    draft = @flow.versions.create!(version_number: 98, status: "draft")
    post publish_flow_flow_version_url(account_id: @account.id, flow_id: @flow, id: draft)
    assert_response :redirect
    follow_redirect!
    assert_match /at least one stage/i, response.body
  end

  test "preview renders for draft" do
    sign_in_as(@admin)
    draft = @flow.versions.create!(version_number: 97, status: "draft")
    draft.stages.create!(
      key: "s1", label: "S1", position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    post preview_flow_flow_version_url(account_id: @account.id, flow_id: @flow, id: draft)
    assert_response :success
    refute_match /cannot preview/i, response.body
  end

  test "non-admin cannot create version" do
    sign_in_as(@operator)
    assert_no_difference -> { @flow.versions.count } do
      post flow_flow_version_index_url(account_id: @account.id, flow_id: @flow),
        params: { flow_version: { version_number: 10 } }
    end
    assert_redirected_to accounts_path
  end
end