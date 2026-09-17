require "test_helper"

class Reservi::PredicateEvaluatorTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:alpha_wilma)
    @conversation = conversations(:alpha_active)
  end

  test "literal true" do
    assert Reservi::PredicateEvaluator.evaluate({ "literal" => true }, {})
  end

  test "literal false" do
    refute Reservi::PredicateEvaluator.evaluate({ "literal" => false }, {})
  end

  test "exists returns true when value present" do
    context = { customer: @customer, conversation: @conversation }
    @customer.update!(custom_values: { "city" => "Marrakech" })
    assert Reservi::PredicateEvaluator.evaluate(
      { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } }, context
    )
  end

  test "exists returns false when value missing" do
    context = { customer: @customer, conversation: @conversation }
    @customer.update!(custom_values: {})
    refute Reservi::PredicateEvaluator.evaluate(
      { "exists" => { "kind" => "field", "scope" => "customer", "key" => "city" } }, context
    )
  end

  test "missing returns true when value absent" do
    context = { customer: @customer, conversation: @conversation }
    @customer.update!(custom_values: {})
    assert Reservi::PredicateEvaluator.evaluate(
      { "missing" => { "kind" => "field", "scope" => "customer", "key" => "city" } }, context
    )
  end

  test "eq matches string value" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "city" => "Marrakech" })
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Marrakech" } }, context
    )
  end

  test "eq returns false for mismatch" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "city" => "Casablanca" })
    refute Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Marrakech" } }, context
    )
  end

  test "eq returns false for missing value" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: {})
    refute Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Marrakech" } }, context
    )
  end

  test "neq returns true when mismatch" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "city" => "Casablanca" })
    assert Reservi::PredicateEvaluator.evaluate(
      { "neq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Marrakech" } }, context
    )
  end

  test "gt works with numeric values" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 500 })
    assert Reservi::PredicateEvaluator.evaluate(
      { "gt" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 100 } }, context
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "gt" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 1000 } }, context
    )
  end

  test "gte works with numeric values" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 500 })
    assert Reservi::PredicateEvaluator.evaluate(
      { "gte" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 500 } }, context
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "gte" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 501 } }, context
    )
  end

  test "lt works with numeric values" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 100 })
    assert Reservi::PredicateEvaluator.evaluate(
      { "lt" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 200 } }, context
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "lt" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 50 } }, context
    )
  end

  test "lte works with numeric values" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 100 })
    assert Reservi::PredicateEvaluator.evaluate(
      { "lte" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 100 } }, context
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "lte" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 99 } }, context
    )
  end

  test "numeric comparison returns false when value is missing" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: {})
    refute Reservi::PredicateEvaluator.evaluate(
      { "gt" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "budget" }, "value" => 100 } }, context
    )
  end

  test "all requires all sub-predicates true" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 500, "city" => "Marrakech" })
    assert Reservi::PredicateEvaluator.evaluate({
      "all" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Marrakech" } }
      ]
    }, context)

    refute Reservi::PredicateEvaluator.evaluate({
      "all" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        { "eq" => { "ref" => { "kind" => "field", "scope" => "conversation", "key" => "city" }, "value" => "Casablanca" } }
      ]
    }, context)
  end

  test "any requires at least one sub-predicate true" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 500 })
    assert Reservi::PredicateEvaluator.evaluate({
      "any" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "city" } }
      ]
    }, context)

    refute Reservi::PredicateEvaluator.evaluate({
      "any" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "city" } },
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "priority" } }
      ]
    }, context)
  end

  test "not inverts predicate" do
    assert Reservi::PredicateEvaluator.evaluate(
      { "not" => { "literal" => false } }, {}
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "not" => { "literal" => true } }, {}
    )
  end

  test "canonical column fields resolve correctly" do
    context = { customer: @customer }
    @customer.update!(name: "Wilma Customer")
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "field", "scope" => "customer", "key" => "name" }, "value" => "Wilma Customer" } }, context
    )
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "field", "scope" => "customer", "key" => "email_address" }, "value" => "wilma@example.com" } }, context
    )
  end

  test "owner reference resolves" do
    context = { owner_id: 42 }
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "owner" }, "value" => 42 } }, context
    )
    refute Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "owner" }, "value" => 1 } }, context
    )
  end

  test "team reference resolves" do
    context = { team_id: 7 }
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "team" }, "value" => 7 } }, context
    )
  end

  test "item selection existence and count resolve by stable role" do
    catalog = @conversation.account.catalogs.create!(title: "Services")
    item = catalog.items.create!(account: @conversation.account, title: "Garden care")
    context = { conversation: @conversation }

    refute Reservi::PredicateEvaluator.evaluate(
      { "exists" => { "kind" => "item_selection", "key" => "requested_service" } }, context
    )

    @conversation.item_selections.create!(
      account: @conversation.account, catalog:, item:,
      role_key: "requested_service", snapshot: { "title" => item.title }
    )

    assert Reservi::PredicateEvaluator.evaluate(
      { "exists" => { "kind" => "item_selection", "key" => "requested_service" } }, context
    )
    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "item_selection", "key" => "requested_service", "attribute" => "count" }, "value" => 1 } }, context
    )
  end

  test "appointment status resolves by stable role" do
    appointment = @conversation.appointments.create!(
      account: @conversation.account, role_key: "consultation",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour,
      duration_minutes: 60, timezone: "UTC", status: "confirmed"
    )

    assert Reservi::PredicateEvaluator.evaluate(
      { "eq" => { "ref" => { "kind" => "appointment", "key" => "consultation", "attribute" => "status" }, "value" => "confirmed" } },
      { conversation: @conversation }
    )
    assert appointment.persisted?
  end

  test "non-hash predicate returns false" do
    refute Reservi::PredicateEvaluator.evaluate("string", {})
    refute Reservi::PredicateEvaluator.evaluate(42, {})
    refute Reservi::PredicateEvaluator.evaluate(nil, {})
  end

  test "unknown operator returns false" do
    refute Reservi::PredicateEvaluator.evaluate({ "unknown_op" => true }, {})
  end

  test "evaluate_with_explanation returns tree" do
    result = Reservi::PredicateEvaluator.evaluate_with_explanation({ "literal" => true }, {})
    assert result[:result]
    assert_equal "Literal true", result[:reason]

    result = Reservi::PredicateEvaluator.evaluate_with_explanation({ "literal" => false }, {})
    refute result[:result]
    assert_equal "Literal false", result[:reason]
  end

  test "explanation for compound predicates" do
    context = { conversation: @conversation }
    @conversation.update!(custom_values: { "budget" => 500 })
    result = Reservi::PredicateEvaluator.evaluate_with_explanation({
      "all" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "city" } }
      ]
    }, context)

    refute result[:result]
    assert_equal "All conditions", result[:reason]
    assert_equal 2, result[:children].length
    assert result[:children][0][:result]
    refute result[:children][1][:result]
  end
end
