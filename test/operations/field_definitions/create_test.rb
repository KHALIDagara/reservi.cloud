require "test_helper"

class FieldDefinitions::CreateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @admin = memberships(:alpha_alice)
  end

  test "admin creates a field definition" do
    defn = FieldDefinitions::Create.call(
      account: @account,
      actor_membership: @admin,
      attributes: { scope: "conversation", key: "budget", field_type: "number", label: "Budget", position: 1 }
    )
    assert defn.persisted?
    assert_equal "budget", defn.key
    assert_equal "conversation", defn.scope
    assert_equal "number", defn.field_type
  end

  test "non-admin cannot create" do
    operator = memberships(:alpha_bob)
    e = assert_raises(Reservi::Errors::AuthorizationError) do
      FieldDefinitions::Create.call(
        account: @account,
        actor_membership: operator,
        attributes: { scope: "conversation", key: "budget", field_type: "number" }
      )
    end
    assert_match /administrator/, e.message
  end

  test "reserved key is rejected" do
    e = assert_raises(Reservi::Errors::OperationError) do
      FieldDefinitions::Create.call(
        account: @account,
        actor_membership: @admin,
        attributes: { scope: "customer", key: "name", field_type: "text" }
      )
    end
    assert_match /built.in/, e.message.downcase
  end

  test "duplicate key in same scope and account fails" do
    FieldDefinitions::Create.call(
      account: @account,
      actor_membership: @admin,
      attributes: { scope: "conversation", key: "test_key", field_type: "text" }
    )
    e = assert_raises(ActiveRecord::RecordInvalid) do
      FieldDefinitions::Create.call(
        account: @account,
        actor_membership: @admin,
        attributes: { scope: "conversation", key: "test_key", field_type: "text" }
      )
    end
    assert_match /already been taken/i, e.message
  end

  test "same key in different scope is allowed" do
    FieldDefinitions::Create.call(
      account: @account,
      actor_membership: @admin,
      attributes: { scope: "customer", key: "priority", field_type: "text" }
    )
    defn = FieldDefinitions::Create.call(
      account: @account,
      actor_membership: @admin,
      attributes: { scope: "conversation", key: "priority", field_type: "text" }
    )
    assert defn.persisted?
    assert_equal "conversation", defn.scope
  end

  test "same key in different account is allowed" do
    beta_account = accounts(:beta)
    beta_admin = memberships(:beta_carol)
    FieldDefinitions::Create.call(
      account: @account,
      actor_membership: @admin,
      attributes: { scope: "conversation", key: "shared_key", field_type: "text" }
    )
    defn = FieldDefinitions::Create.call(
      account: beta_account,
      actor_membership: beta_admin,
      attributes: { scope: "conversation", key: "shared_key", field_type: "text" }
    )
    assert defn.persisted?
  end

  test "invalid field type is rejected" do
    e = assert_raises(ActiveRecord::RecordInvalid) do
      FieldDefinitions::Create.call(
        account: @account,
        actor_membership: @admin,
        attributes: { scope: "conversation", key: "bad_type", field_type: "color" }
      )
    end
    assert_match /field type/i, e.message
  end

  test "invalid scope is rejected" do
    e = assert_raises(ActiveRecord::RecordInvalid) do
      FieldDefinitions::Create.call(
        account: @account,
        actor_membership: @admin,
        attributes: { scope: "project", key: "test", field_type: "text" }
      )
    end
    assert_match /scope/i, e.message
  end
end
