require "test_helper"

class Flows::PublishTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
    @flow = flows(:alpha_default)
  end

  test "publishes a draft version" do
    version = @flow.versions.create!(version_number: 2, status: "draft")
    version.stages.create!(
      key: "stage_1",
      label: "Intake",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
    assert result.published_at.present?

    @flow.reload
    assert_equal version.id, @flow.current_version_id
  end

  test "non-admin cannot publish" do
    operator = memberships(:alpha_bob)
    version = @flow.versions.create!(version_number: 2, status: "draft")
    version.stages.create!(
      key: "stage_1",
      label: "Intake",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )

    e = assert_raises(Reservi::Errors::AuthorizationError) do
      Flows::Publish.call(flow_version: version, actor_membership: operator)
    end
    assert_match /administrator/i, e.message
  end

  test "cannot publish already published version" do
    version = flow_versions(:alpha_v1)
    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /already published/i, e.message
  end

  test "cannot publish version without stages" do
    version = @flow.versions.create!(version_number: 3, status: "draft")
    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /at least one stage/i, e.message
  end

  test "rejects unsupported block type" do
    version = @flow.versions.create!(version_number: 4, status: "draft")
    version.stages.create!(
      key: "bad_block",
      label: "Bad Block",
      position: 1,
      blocks: [{ "type" => "unsupported_widget" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /unsupported block/i, e.message
    assert_match /bad_block/i, e.message
  end

  test "rejects unsupported rule action type" do
    version = @flow.versions.create!(version_number: 5, status: "draft")
    version.stages.create!(
      key: "bad_rule",
      label: "Bad Rule",
      position: 1,
      blocks: [],
      rules: [{ "key" => "rule1", "actions" => [{ "type" => "delete_everything" }] }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /unsupported action/i, e.message
    assert_match /bad_rule/i, e.message
  end

  test "allows field block type" do
    version = @flow.versions.create!(version_number: 6, status: "draft")
    version.stages.create!(
      key: "field_stage",
      label: "Field Stage",
      position: 1,
      blocks: [{ "type" => "field", "key" => "budget" }],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "allows catalog block type" do
    version = @flow.versions.create!(version_number: 7, status: "draft")
    version.stages.create!(
      key: "catalog_stage",
      label: "Catalog Stage",
      position: 1,
      blocks: [{ "type" => "catalog", "catalog_key" => "services", "role_key" => "requested_service" }],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "allows appointment block type" do
    version = @flow.versions.create!(version_number: 8, status: "draft")
    version.stages.create!(
      key: "appt_stage",
      label: "Appointment Stage",
      position: 1,
      blocks: [{ "type" => "appointment", "role_key" => "consultation" }],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "allows assign action type" do
    version = @flow.versions.create!(version_number: 9, status: "draft")
    version.stages.create!(
      key: "assign_stage",
      label: "Assign Stage",
      position: 1,
      blocks: [],
      rules: [{ "key" => "assign_rule", "actions" => [{ "type" => "assign" }] }],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "allows send_message action type" do
    version = @flow.versions.create!(version_number: 10, status: "draft")
    version.stages.create!(
      key: "msg_stage",
      label: "Msg Stage",
      position: 1,
      blocks: [],
      rules: [{ "key" => "msg_rule", "actions" => [{ "type" => "send_message" }] }],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  # ── Additional publish validation tests ──────────────────────────────

  test "rejects invalid stage key format" do
    version = @flow.versions.create!(version_number: 20, status: "draft")
    version.stages.create!(
      key: "Bad Key!",
      label: "Bad Key",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /Invalid stage key/, e.message
    assert_match /Bad Key!/, e.message
  end

  test "rejects duplicate stage keys" do
    version = @flow.versions.create!(version_number: 21, status: "draft")
    version.stages.create!(
      key: "same_key",
      label: "First",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    version.stages.create!(
      key: "other_key",
      label: "Second",
      position: 2,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    # Temporarily drop the unique index on (flow_version_id, key) so we can
    # inject a duplicate key and test the publish-level validation.
    index_name = "index_stages_on_flow_version_id_and_key"
    Stage.connection.execute("DROP INDEX IF EXISTS #{index_name}")
    Stage.connection.execute(
      "UPDATE stages SET key = 'same_key' WHERE position = 2 AND flow_version_id = #{version.id}"
    )
    version.stages.reload

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /Duplicate stage keys/, e.message
    assert_match /same_key/, e.message
  end

  test "rejects duplicate stage positions" do
    version = @flow.versions.create!(version_number: 22, status: "draft")
    version.stages.create!(
      key: "one",
      label: "First",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    version.stages.create!(
      key: "two",
      label: "Second",
      position: 2,
      blocks: [],
      rules: [],
      completion: { "literal" => false }
    )
    # Temporarily drop the unique index on (flow_version_id, position) so we can
    # inject a duplicate position and test the publish-level validation.
    index_name = "index_stages_on_flow_version_id_and_position"
    Stage.connection.execute("DROP INDEX IF EXISTS #{index_name}")
    Stage.connection.execute(
      "UPDATE stages SET position = 1 WHERE key = 'two' AND flow_version_id = #{version.id}"
    )
    version.stages.reload

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /Duplicate stage positions/, e.message
  end

  test "rejects field block without key" do
    version = @flow.versions.create!(version_number: 23, status: "draft")
    version.stages.create!(
      key: "field_no_key",
      label: "Field No Key",
      position: 1,
      blocks: [{ "type" => "field" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /field block must specify a field key/i, e.message
    assert_match /field_no_key/i, e.message
  end

  test "rejects catalog block without catalog_key" do
    version = @flow.versions.create!(version_number: 24, status: "draft")
    version.stages.create!(
      key: "catalog_no_key",
      label: "Catalog No Key",
      position: 1,
      blocks: [{ "type" => "catalog" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /catalog block must specify a catalog key/i, e.message
    assert_match /catalog_no_key/i, e.message
  end

  test "rejects appointment block without role_key" do
    version = @flow.versions.create!(version_number: 25, status: "draft")
    version.stages.create!(
      key: "appt_no_role",
      label: "Appt No Role",
      position: 1,
      blocks: [{ "type" => "appointment" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /appointment block must specify a role key/i, e.message
    assert_match /appt_no_role/i, e.message
  end

  test "rejects rule without key" do
    version = @flow.versions.create!(version_number: 26, status: "draft")
    version.stages.create!(
      key: "no_key_rule",
      label: "No Key Rule",
      position: 1,
      blocks: [],
      rules: [{ "actions" => [{ "type" => "assign" }] }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /rule must have a key/i, e.message
    assert_match /no_key_rule/i, e.message
  end

  test "rejects unsupported predicate operator" do
    version = @flow.versions.create!(version_number: 27, status: "draft")
    version.stages.create!(
      key: "bad_op",
      label: "Bad Operator",
      position: 1,
      blocks: [],
      rules: [{ "key" => "r1", "predicate" => { "custom_op" => {} } }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /unsupported predicate operator/i, e.message
    assert_match /custom_op/i, e.message
  end

  test "rejects empty completion predicate" do
    version = @flow.versions.create!(version_number: 28, status: "draft")
    version.stages.create!(
      key: "empty_comp",
      label: "Empty Completion",
      position: 1,
      blocks: [],
      rules: [],
      completion: {}
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /completion predicate is empty/i, e.message
    assert_match /empty_comp/i, e.message
  end

  test "rejects excessive rules per stage" do
    version = @flow.versions.create!(version_number: 29, status: "draft")
    rules = (1..51).map { |i| { "key" => "rule_#{i}", "actions" => [{ "type" => "assign" }] } }
    version.stages.create!(
      key: "too_many_rules",
      label: "Too Many Rules",
      position: 1,
      blocks: [],
      rules: rules,
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /exceeds maximum.*rules/i, e.message
    assert_match /too_many_rules/i, e.message
  end

  test "rejects excessive actions per rule" do
    version = @flow.versions.create!(version_number: 30, status: "draft")
    actions = (1..11).map { |i| { "type" => "assign" } }
    version.stages.create!(
      key: "too_many_actions",
      label: "Too Many Actions",
      position: 1,
      blocks: [],
      rules: [{ "key" => "rule1", "actions" => actions }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /exceeds maximum.*actions/i, e.message
    assert_match /too_many_actions/i, e.message
  end

  test "rejects AST exceeding max depth" do
    version = @flow.versions.create!(version_number: 31, status: "draft")
    # Build a chain of nested all/not expressions deeper than MAX_AST_DEPTH (10)
    nested = { "literal" => true }
    12.times { nested = { "not" => nested } }

    version.stages.create!(
      key: "deep_ast",
      label: "Deep AST",
      position: 1,
      blocks: [],
      rules: [],
      completion: nested
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /AST depth exceeds maximum/i, e.message
    assert_match /deep_ast/i, e.message
  end

  test "rejects unsupported reference kind" do
    version = @flow.versions.create!(version_number: 32, status: "draft")
    version.stages.create!(
      key: "bad_ref",
      label: "Bad Ref",
      position: 1,
      blocks: [],
      rules: [{
        "key" => "r1",
        "predicate" => {
          "exists" => { "kind" => "widget", "key" => "city" }
        }
      }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /unsupported reference kind/i, e.message
    assert_match /widget/i, e.message
  end

  test "rejects invalid field scope" do
    version = @flow.versions.create!(version_number: 33, status: "draft")
    version.stages.create!(
      key: "bad_scope",
      label: "Bad Scope",
      position: 1,
      blocks: [],
      rules: [{
        "key" => "r1",
        "predicate" => {
          "exists" => { "kind" => "field", "scope" => "organization", "key" => "city" }
        }
      }],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /invalid field scope/i, e.message
    assert_match /organization/i, e.message
  end

  test "rejects bushy AST exceeding max nodes (not depth)" do
    version = @flow.versions.create!(version_number: 34, status: "draft")
    # Build a wide 'all' with many children — each child is one node.
    # total nodes = 1 (the root all) + 150 children = 151 > MAX_AST_NODES (100)
    children = (1..150).map { |_| { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } } }
    wide_ast = { "all" => children }

    version.stages.create!(
      key: "wide_ast",
      label: "Wide AST",
      position: 1,
      blocks: [],
      rules: [],
      completion: wide_ast
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /AST node count exceeds maximum/i, e.message
    assert_match /wide_ast/i, e.message
  end

  test "rejects conflicting role keys across stages (catalog vs appointment)" do
    version = @flow.versions.create!(version_number: 35, status: "draft")
    version.stages.create!(
      key: "stage_a",
      label: "Stage A",
      position: 1,
      blocks: [{ "type" => "catalog", "catalog_key" => "services", "role_key" => "selection" }],
      rules: [],
      completion: { "literal" => true }
    )
    version.stages.create!(
      key: "stage_b",
      label: "Stage B",
      position: 2,
      blocks: [{ "type" => "appointment", "role_key" => "selection" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /conflicts with/, e.message
    assert_match /selection/, e.message
  end

  test "rejects conflicting catalog role keys across stages" do
    version = @flow.versions.create!(version_number: 36, status: "draft")
    version.stages.create!(
      key: "stage_a",
      label: "Stage A",
      position: 1,
      blocks: [{ "type" => "catalog", "catalog_key" => "services", "role_key" => "my_role" }],
      rules: [],
      completion: { "literal" => true }
    )
    version.stages.create!(
      key: "stage_b",
      label: "Stage B",
      position: 2,
      blocks: [{ "type" => "catalog", "catalog_key" => "vehicles", "role_key" => "my_role" }],
      rules: [],
      completion: { "literal" => true }
    )

    e = assert_raises(Reservi::Errors::OperationError) do
      Flows::Publish.call(flow_version: version, actor_membership: @admin)
    end
    assert_match /catalog role.*previously referenced with catalog/i, e.message
    assert_match /my_role/i, e.message
  end
end