require "test_helper"

class FieldValueValidatorTest < ActiveSupport::TestCase
  # Helper to build a keyed definition hash rather than an unkeyed FieldDefinition.
  # This matches how validate_values works: it looks up definitions by their key attribute.
  def text_def(key:)
    FieldDefinition.new(key: key.to_s, field_type: "text", constraints: {})
  end

  def number_def(key:, min: nil, max: nil)
    constraints = {}
    constraints["min"] = min if min
    constraints["max"] = max if max
    FieldDefinition.new(key: key.to_s, field_type: "number", constraints: constraints)
  end

  def bool_def(key:)
    FieldDefinition.new(key: key.to_s, field_type: "boolean", constraints: {})
  end

  def single_def(key:, options:)
    FieldDefinition.new(key: key.to_s, field_type: "single_choice", options: options, constraints: {})
  end

  def multi_def(key:, options:)
    FieldDefinition.new(key: key.to_s, field_type: "multi_choice", options: options, constraints: {})
  end

  def date_def(key:)
    FieldDefinition.new(key: key.to_s, field_type: "date", constraints: {})
  end

  test "false and zero persist as real answers" do
    # boolean false is valid
    result = FieldValueValidator.validate_values({ "active" => false }, [ bool_def(key: "active") ])
    assert result[:valid], "false should be valid for boolean"

    # number 0 is valid
    result = FieldValueValidator.validate_values({ "count" => 0 }, [ number_def(key: "count") ])
    assert result[:valid], "0 should be valid for number"

    # number 0.0 is valid
    result = FieldValueValidator.validate_values({ "amount" => 0.0 }, [ number_def(key: "amount") ])
    assert result[:valid], "0.0 should be valid for number"

    # text empty string is valid
    result = FieldValueValidator.validate_values({ "name" => "" }, [ text_def(key: "name") ])
    assert result[:valid], "empty string should be valid for text"
  end

  test "invalid types are rejected" do
    # string in a number field
    result = FieldValueValidator.validate_values({ "count" => "hello" }, [ number_def(key: "count") ])
    assert_not result[:valid]
    assert result[:errors]["count"].any?

    # number in a boolean field
    result = FieldValueValidator.validate_values({ "active" => 1 }, [ bool_def(key: "active") ])
    assert_not result[:valid]

    # string in a boolean field
    result = FieldValueValidator.validate_values({ "active" => "true" }, [ bool_def(key: "active") ])
    assert_not result[:valid]
  end

  test "nil is allowed for any type" do
    result = FieldValueValidator.validate_values({ "active" => nil }, [ bool_def(key: "active") ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "count" => nil }, [ number_def(key: "count") ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "name" => nil }, [ text_def(key: "name") ])
    assert result[:valid]
  end

  test "single choice validates against allowed options" do
    defn = single_def(key: "urgency", options: [ { "key" => "low", "label" => "Low" }, { "key" => "high", "label" => "High" } ])

    result = FieldValueValidator.validate_values({ "urgency" => "low" }, [ defn ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "urgency" => "medium" }, [ defn ])
    assert_not result[:valid]
  end

  test "single choice uses string comparison" do
    defn = single_def(key: "val", options: [ { "key" => "123", "label" => "Number key" } ])

    result = FieldValueValidator.validate_values({ "val" => 123 }, [ defn ])
    assert result[:valid], "Integer 123 should match string key '123'"

    result = FieldValueValidator.validate_values({ "val" => 456 }, [ defn ])
    assert_not result[:valid], "Integer 456 should not match string key '123'"
  end

  test "multi choice validates all values" do
    defn = multi_def(key: "tags", options: [ { "key" => "a", "label" => "A" }, { "key" => "b", "label" => "B" } ])

    result = FieldValueValidator.validate_values({ "tags" => [ "a", "b" ] }, [ defn ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "tags" => [ "a", "c" ] }, [ defn ])
    assert_not result[:valid]
    assert result[:errors]["tags"].first.include?("c")
  end

  test "date validates format" do
    result = FieldValueValidator.validate_values({ "date" => "2026-09-13" }, [ date_def(key: "date") ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "date" => "not-a-date" }, [ date_def(key: "date") ])
    assert_not result[:valid]
  end

  test "unknown keys are ignored" do
    result = FieldValueValidator.validate_values({ "unknown" => "value" }, [ text_def(key: "other") ])
    assert result[:valid]
  end

  test "number respects min/max constraints" do
    defn = number_def(key: "val", min: 0, max: 100)

    result = FieldValueValidator.validate_values({ "val" => 50 }, [ defn ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "val" => -1 }, [ defn ])
    assert_not result[:valid]

    result = FieldValueValidator.validate_values({ "val" => 101 }, [ defn ])
    assert_not result[:valid]
  end

  test "boolean accepts true and false only" do
    result = FieldValueValidator.validate_values({ "active" => true }, [ bool_def(key: "active") ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "active" => false }, [ bool_def(key: "active") ])
    assert result[:valid]

    result = FieldValueValidator.validate_values({ "active" => "true" }, [ bool_def(key: "active") ])
    assert_not result[:valid]

    result = FieldValueValidator.validate_values({ "active" => 0 }, [ bool_def(key: "active") ])
    assert_not result[:valid]
  end
end
