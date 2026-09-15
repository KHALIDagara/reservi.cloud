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

  # ── Composition tests (T09 acceptance criteria) ───────────────────────

  test "field-only flow publishes successfully" do
    version = @flow.versions.create!(version_number: 40, status: "draft")
    version.stages.create!(
      key: "collect_info",
      label: "Collect Info",
      position: 1,
      blocks: [
        { "type" => "field", "key" => "city" },
        { "type" => "field", "key" => "budget" }
      ],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } }
    )
    version.stages.create!(
      key: "confirm_details",
      label: "Confirm Details",
      position: 2,
      blocks: [
        { "type" => "field", "key" => "surface" }
      ],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "surface" } }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "catalog-only flow publishes successfully" do
    version = @flow.versions.create!(version_number: 41, status: "draft")
    version.stages.create!(
      key: "select_service",
      label: "Select Service",
      position: 1,
      blocks: [
        { "type" => "catalog", "catalog_key" => "services", "role_key" => "requested_service" }
      ],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "service" } }
    )
    version.stages.create!(
      key: "add_extras",
      label: "Add Extras",
      position: 2,
      blocks: [
        { "type" => "catalog", "catalog_key" => "extras", "role_key" => "extras" }
      ],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "appointment-only flow publishes successfully" do
    version = @flow.versions.create!(version_number: 42, status: "draft")
    version.stages.create!(
      key: "schedule_visit",
      label: "Schedule Visit",
      position: 1,
      blocks: [
        { "type" => "appointment", "role_key" => "consultation" }
      ],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "visit" } }
    )
    version.stages.create!(
      key: "confirm_appointment",
      label: "Confirm Appointment",
      position: 2,
      blocks: [
        { "type" => "appointment", "role_key" => "followup" }
      ],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "appointment-first flow publishes (appointment before catalog)" do
    version = @flow.versions.create!(version_number: 43, status: "draft")
    # Stage 1: appointment block
    version.stages.create!(
      key: "pickup_time",
      label: "Pickup Time",
      position: 1,
      blocks: [
        { "type" => "appointment", "role_key" => "pickup" }
      ],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "pickup" } }
    )
    # Stage 2: catalog block
    version.stages.create!(
      key: "choose_vehicle",
      label: "Choose Vehicle",
      position: 2,
      blocks: [
        { "type" => "catalog", "catalog_key" => "vehicles", "role_key" => "vehicle" }
      ],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "catalog-first flow publishes (catalog before appointment)" do
    version = @flow.versions.create!(version_number: 44, status: "draft")
    # Stage 1: catalog blocks
    version.stages.create!(
      key: "choose_vehicle",
      label: "Choose Vehicle",
      position: 1,
      blocks: [
        { "type" => "catalog", "catalog_key" => "vehicles", "role_key" => "vehicle" },
        { "type" => "catalog", "catalog_key" => "services", "role_key" => "service" }
      ],
      rules: [],
      completion: { "literal" => true }
    )
    # Stage 2: appointment block
    version.stages.create!(
      key: "schedule_pickup",
      label: "Schedule Pickup",
      position: 2,
      blocks: [
        { "type" => "appointment", "role_key" => "pickup" }
      ],
      rules: [],
      completion: { "literal" => true }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "multi-block single stage publishes (field + catalog + appointment)" do
    version = @flow.versions.create!(version_number: 45, status: "draft")
    version.stages.create!(
      key: "comprehensive",
      label: "Comprehensive",
      position: 1,
      blocks: [
        { "type" => "field", "key" => "city" },
        { "type" => "catalog", "catalog_key" => "services", "role_key" => "requested_service" },
        { "type" => "appointment", "role_key" => "consultation" }
      ],
      rules: [
        {
          "key" => "assign_after_field",
          "predicate" => { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } },
          "actions" => [{ "type" => "assign" }]
        }
      ],
      completion: {
        "all" => [
          { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } },
          { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "service" } },
          { "literal" => true }
        ]
      }
    )

    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?
  end

  test "preview-side effect free: predicate evaluation does not enqueue jobs" do
    version = @flow.versions.create!(version_number: 46, status: "draft")
    version.stages.create!(
      key: "preview_stage",
      label: "Preview Stage",
      position: 1,
      blocks: [
        { "type" => "field", "key" => "city" }
      ],
      rules: [],
      completion: {
        "all" => [
          { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } },
          { "neq" => { "ref" => { "kind" => "field", "scope" => "customer", "key" => "city" }, "value" => "" } }
        ]
      }
    )

    # Verify the flow publishes
    result = Flows::Publish.call(flow_version: version, actor_membership: @admin)
    assert result.published?

    # Now test that predicate evaluation (as used in preview) is side-effect free
    context = {
      customer: customers(:alpha_wilma),
      conversation: conversations(:alpha_active),
      owner_id: nil,
      team_id: nil
    }

    assert_no_enqueued_jobs do
      Reservi::PredicateEvaluator.evaluate_with_explanation(
        { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } },
        context
      )
    end
  end

  test "in-flight conversation unaffected by publishing a new version" do
    @conversation = conversations(:alpha_active)
    original_flow_version_id = @conversation.flow_version_id
    original_stage_id = @conversation.current_stage_id

    assert_equal flow_versions(:alpha_v1).id, original_flow_version_id

    # Create a completely new draft version with different stages
    new_version = @flow.versions.create!(version_number: 99, status: "draft")
    new_version.stages.create!(
      key: "new_stage_a",
      label: "New Stage A",
      position: 1,
      blocks: [{ "type" => "field", "key" => "budget" }],
      rules: [],
      completion: { "literal" => false }
    )
    new_version.stages.create!(
      key: "new_stage_b",
      label: "New Stage B",
      position: 2,
      blocks: [{ "type" => "catalog", "catalog_key" => "services", "role_key" => "service" }],
      rules: [],
      completion: { "literal" => true }
    )

    # Publish v99
    result = Flows::Publish.call(flow_version: new_version, actor_membership: @admin)
    assert result.published?
    @flow.reload
    assert_equal new_version.id, @flow.current_version_id, "Flow.current_version should point to v99"

    # In-flight conversation must still be pinned to alpha_v1
    @conversation.reload
    assert_equal original_flow_version_id, @conversation.flow_version_id,
      "Conversation must stay pinned to alpha_v1"
    assert_equal original_stage_id, @conversation.current_stage_id,
      "Conversation current_stage must be unchanged"
    assert @conversation.active?, "Conversation should still be active"
  end

  # ── Soft warnings ────────────────────────────────────────────────────

  test "missing field definition emits warning but publishes" do
    version = @flow.versions.create!(version_number: 50, status: "draft")
    version.stages.create!(
      key: "missing_field_stage",
      label: "Missing Field Stage",
      position: 1,
      blocks: [{ "type" => "field", "key" => "non_existent_field" }],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "customer", "key" => "non_existent_field" } }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    result = publisher.call

    assert result.published?, "Version should publish even with missing field"
    assert_equal 1, publisher.warnings.size, "Should have one warning"
    assert_match(/no active field definition/i, publisher.warnings.first)
  end

  test "missing catalog key emits warning but publishes" do
    version = @flow.versions.create!(version_number: 51, status: "draft")
    version.stages.create!(
      key: "missing_catalog_stage",
      label: "Missing Catalog Stage",
      position: 1,
      blocks: [{ "type" => "catalog", "catalog_key" => "non_existent_catalog", "role_key" => "my_role" }],
      rules: [],
      completion: { "literal" => true }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    result = publisher.call

    assert result.published?, "Version should publish even with missing catalog"
    assert_equal 1, publisher.warnings.size, "Should have one warning"
    assert_match(/not found in account/i, publisher.warnings.first)
  end

  test "missing agent in assign action emits warning but publishes" do
    version = @flow.versions.create!(version_number: 52, status: "draft")
    version.stages.create!(
      key: "missing_agent_stage",
      label: "Missing Agent Stage",
      position: 1,
      blocks: [],
      rules: [
        {
          "key" => "assign_to_unknown",
          "predicate" => { "literal" => true },
          "actions" => [{ "type" => "assign", "agent_id" => 99999 }]
        }
      ],
      completion: { "literal" => true }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    result = publisher.call

    assert result.published?, "Version should publish even with unknown agent"
    assert_equal 1, publisher.warnings.size, "Should have one warning"
    assert_match(/unknown agent/i, publisher.warnings.first)
  end

  test "multiple warnings accumulate and publish still succeeds" do
    version = @flow.versions.create!(version_number: 53, status: "draft")
    version.stages.create!(
      key: "multi_warning",
      label: "Multi Warning",
      position: 1,
      blocks: [
        { "type" => "catalog", "catalog_key" => "missing_catalog", "role_key" => "role1" },
        { "type" => "catalog", "catalog_key" => "another_missing", "role_key" => "role2" }
      ],
      rules: [
        {
          "key" => "rule_with_missing",
          "predicate" => { "exists" => { "kind" => "field", "scope" => "customer", "key" => "missing_field" } },
          "actions" => [{ "type" => "assign", "agent_id" => 88888 }]
        }
      ],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "missing_key" } }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    result = publisher.call

    assert result.published?, "Version should publish with multiple warnings"
    assert_equal 5, publisher.warnings.size, "Should accumulate all 5 warnings (2 catalogs + 2 fields + 1 agent)"
  end

  # Cross-account reference validation (TODO: implement when cross-account checks are added)
  #
  # Acceptance criterion: "cross-account targets fail publish"
  # The current publish validation checks reference kinds but does not yet validate
  # that agent references (in assign actions) belong to the same account as the flow.
  # When implemented, tests should cover:
  #   - Assign action referencing beta account's agent from alpha's flow
  #   - Catalog role referencing beta account's catalog
  #   - Field reference by key that exists in another account
  # test "cross-account catalog reference blocked" do
  #   skip "Cross-account validation not yet implemented"
  # end

  # ── Archived/deactivated target warnings ──────────────────────────

  test "warns on archived catalog reference" do
    # Create a catalog, then archive it
    catalog = @account.catalogs.create!(title: "soon_archived")
    catalog.update!(archived: true)
    
    version = @flow.versions.create!(version_number: 70, status: "draft")
    version.stages.create!(
      key: "s1",
      label: "S1",
      position: 1,
      blocks: [{ "type" => "catalog", "catalog_key" => "soon_archived", "role_key" => "r1" }],
      rules: [],
      completion: { "literal" => true }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    publisher.call
    assert publisher.warnings.any? { |w| w.include?("soon_archived") && w.include?("not found") },
      "Should warn about archived catalog not being found in active scope"
  end

  test "warns on deactivated agent in assign action" do
    # Deactivate the agent directly (not just the membership)
    bob_agent = agents(:alpha_bob_human)
    bob_agent.update!(active: false)
    
    version = @flow.versions.create!(version_number: 71, status: "draft")
    version.stages.create!(
      key: "s1",
      label: "S1",
      position: 1,
      blocks: [],
      rules: [{ "key" => "assign_bob", "actions" => [{ "type" => "assign", "agent_id" => bob_agent.id }] }],
      completion: { "literal" => true }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    publisher.call
    assert publisher.warnings.any? { |w| w.include?("unknown agent") && w.include?(bob_agent.id.to_s) },
      "Should warn about deactivated agent not being found in active scope"
  ensure
    bob_agent&.update!(active: true)
  end

  test "warns on archived field definition in predicate" do
    fd = @account.field_definitions.create!(
      scope: "conversation",
      key: "temp_field",
      field_type: "text",
      label: "Temporary Field"
    )
    fd.update!(archived: true)
    
    version = @flow.versions.create!(version_number: 72, status: "draft")
    version.stages.create!(
      key: "s1",
      label: "S1",
      position: 1,
      blocks: [],
      rules: [],
      completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "temp_field" } }
    )

    publisher = Flows::Publish.new(flow_version: version, actor_membership: @admin)
    publisher.call
    assert publisher.warnings.any? { |w| w.include?("temp_field") && w.include?("no active field definition") },
      "Should warn about archived field definition"
  end
end