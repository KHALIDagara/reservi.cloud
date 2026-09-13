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
      blocks: [{ "type" => "catalog", "catalog_key" => "services" }],
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
      blocks: [{ "type" => "appointment" }],
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
end