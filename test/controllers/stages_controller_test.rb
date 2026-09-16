require "test_helper"

class Accounts::StagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    @admin = users(:alice)
    @operator = users(:bob)
    @flow = @account.flows.first
    @published = @flow.versions.first
  end

  def draft_version
    @draft_version ||= begin
      v = @flow.versions.create!(version_number: 50, status: "draft")
      v.stages.create!(key: "test", label: "Test", position: 1, blocks: [], rules: [], completion: { "literal" => false })
      v
    end
  end

  def stage
    @stage ||= draft_version.stages.first
  end

  # --- new ---

  test "new renders form for admin" do
    sign_in_as(@admin)
    get new_flow_flow_version_stage_path(@account, @flow, draft_version)
    assert_response :success
    assert_select "form"
  end

  test "new redirects non-admin" do
    sign_in_as(@operator)
    get new_flow_flow_version_stage_path(@account, @flow, draft_version)
    assert_redirected_to accounts_path
  end

  # --- create ---

  test "create adds stage to draft version" do
    sign_in_as(@admin)
    assert_difference -> { draft_version.stages.count } => 1 do
      post flow_flow_version_stages_path(@account, @flow, draft_version),
        params: { stage: { key: "stage_2", label: "Follow-up", position: 2 } }
    end
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, draft_version)
    assert_match /Stage added/, flash[:notice]
  end

  test "create with blocks, rules, and completion" do
    sign_in_as(@admin)
    assert_difference -> { draft_version.stages.count } => 1 do
      post flow_flow_version_stages_path(@account, @flow, draft_version),
        params: {
          stage: { key: "stage_2", label: "Budget Check", position: 2 },
          blocks: {
            "0" => { type: "field", key: "budget" }
          },
          rules: {
            "0" => {
              key: "rule1",
              predicate_type: "exists",
              predicate_scope: "conversation",
              predicate_key: "budget",
              actions: {
                "0" => { type: "assign" }
              }
            }
          },
          completion: { type: "literal", value: "false" }
        }
    end
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, draft_version)

    new_stage = draft_version.stages.find_by(key: "stage_2")
    assert new_stage
    assert_equal "Budget Check", new_stage.label
    assert_equal 2, new_stage.position
    assert_equal [ { "type" => "field", "key" => "budget", "required" => false } ], new_stage.blocks
    expected_rules = [
      {
        "key" => "rule1",
        "predicate" => { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        "actions" => [ { "type" => "assign" } ]
      }
    ]
    assert_equal expected_rules, new_stage.rules
    assert_equal({ "literal" => false }, new_stage.completion)
  end

  test "create fails with invalid params" do
    sign_in_as(@admin)
    assert_no_difference -> { draft_version.stages.count } do
      post flow_flow_version_stages_path(@account, @flow, draft_version),
        params: { stage: { key: "", label: "", position: nil } }
    end
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "non-admin cannot create stage" do
    sign_in_as(@operator)
    assert_no_difference -> { draft_version.stages.count } do
      post flow_flow_version_stages_path(@account, @flow, draft_version),
        params: { stage: { key: "stage_2", label: "Follow-up", position: 2 } }
    end
    assert_redirected_to accounts_path
  end

  test "published version cannot create stage" do
    sign_in_as(@admin)
    assert_no_difference -> { @published.stages.count } do
      post flow_flow_version_stages_path(@account, @flow, @published),
        params: { stage: { key: "stage_2", label: "Follow-up", position: 2 } }
    end
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, @published)
    assert_match /Cannot modify a published version/, flash[:alert]
  end

  # --- edit ---

  test "edit renders form for admin" do
    sign_in_as(@admin)
    get edit_flow_flow_version_stage_path(@account, @flow, draft_version, stage)
    assert_response :success
    assert_select "form"
  end

  test "edit redirects non-admin" do
    sign_in_as(@operator)
    get edit_flow_flow_version_stage_path(@account, @flow, draft_version, stage)
    assert_redirected_to accounts_path
  end

  # --- update ---

  test "update saves changes to stage" do
    sign_in_as(@admin)
    patch flow_flow_version_stage_path(@account, @flow, draft_version, stage),
      params: {
        stage: { key: "updated_key", label: "Updated Label", position: 1 },
        blocks: {},
        rules: {},
        completion: { type: "literal", value: "true" }
      }
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, draft_version)
    assert_match /Stage updated/, flash[:notice]

    stage.reload
    assert_equal "updated_key", stage.key
    assert_equal "Updated Label", stage.label
  end

  test "update with blocks, rules, and completion" do
    sign_in_as(@admin)
    patch flow_flow_version_stage_path(@account, @flow, draft_version, stage),
      params: {
        stage: { key: stage.key, label: "Updated", position: stage.position },
        blocks: { "0" => { type: "field", key: "budget" } },
        rules: {
          "0" => {
            key: "rule1",
            predicate_type: "exists",
            predicate_scope: "conversation",
            predicate_key: "budget",
            actions: { "0" => { type: "assign" } }
          }
        },
        completion: { type: "exists", scope: "conversation", key: "budget" }
      }
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, draft_version)

    stage.reload
    assert_equal "Updated", stage.label
    assert_equal [ { "type" => "field", "key" => "budget", "required" => false } ], stage.blocks
    assert_equal({ "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } }, stage.completion)
  end

  test "update fails with invalid params" do
    sign_in_as(@admin)
    patch flow_flow_version_stage_path(@account, @flow, draft_version, stage),
      params: {
        stage: { key: "", label: "", position: nil },
        blocks: {},
        rules: {},
        completion: { type: "literal", value: "false" }
      }
    assert_response :unprocessable_entity
  end

  test "published version cannot update stage" do
    sign_in_as(@admin)
    pub_stage = @published.stages.first
    patch flow_flow_version_stage_path(@account, @flow, @published, pub_stage),
      params: {
        stage: { label: "Hacked" },
        blocks: {},
        rules: {},
        completion: { type: "literal", value: "false" }
      }
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, @published)
    assert_match /Cannot modify a published version/, flash[:alert]
    assert_equal "Intake", pub_stage.reload.label
  end

  test "non-admin cannot update stage" do
    sign_in_as(@operator)
    patch flow_flow_version_stage_path(@account, @flow, draft_version, stage),
      params: {
        stage: { label: "Hacked" },
        blocks: {},
        rules: {},
        completion: { type: "literal", value: "false" }
      }
    assert_redirected_to accounts_path
  end

  # --- destroy ---

  test "destroy removes stage from draft version" do
    sign_in_as(@admin)
    assert_difference -> { draft_version.stages.count } => -1 do
      delete flow_flow_version_stage_path(@account, @flow, draft_version, stage)
    end
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, draft_version)
    assert_match /Stage removed/, flash[:notice]
  end

  test "published version cannot destroy stage" do
    sign_in_as(@admin)
    pub_stage = @published.stages.first
    assert_no_difference -> { @published.stages.count } do
      delete flow_flow_version_stage_path(@account, @flow, @published, pub_stage)
    end
    assert_redirected_to edit_flow_flow_version_path(@account, @flow, @published)
    assert_match /Cannot modify a published version/, flash[:alert]
  end

  test "non-admin cannot destroy stage" do
    sign_in_as(@operator)
    assert_no_difference -> { draft_version.stages.count } do
      delete flow_flow_version_stage_path(@account, @flow, draft_version, stage)
    end
    assert_redirected_to accounts_path
  end
end
