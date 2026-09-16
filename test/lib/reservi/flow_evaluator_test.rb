require "test_helper"

class Reservi::FlowEvaluatorTest < ActiveSupport::TestCase
  setup do
    @conversation = conversations(:alpha_active)
  end

  test "returns not complete when completion predicate is literal false" do
    # alpha_stage1 has completion: { literal: false }
    result = Reservi::FlowEvaluator.evaluate(@conversation)
    refute result[:complete]
    assert_equal "Literal false", result[:explanation][:reason]
  end

  test "returns complete when predicate becomes true" do
    # Set budget to trigger the exists check — but alpha_stage1 uses literal false
    # We need a stage with a predicate that can be satisfied
    stage = @conversation.current_stage
    stage.update!(completion: { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } })
    @conversation.update!(custom_values: { "budget" => 500 })

    result = Reservi::FlowEvaluator.evaluate(@conversation)
    assert result[:complete]
    assert_match /exists/, result[:explanation][:reason]
  end

  test "returns complete for literal true" do
    stage = @conversation.current_stage
    stage.update!(completion: { "literal" => true })

    result = Reservi::FlowEvaluator.evaluate(@conversation)
    assert result[:complete]
  end

  test "returns explanation tree" do
    result = Reservi::FlowEvaluator.evaluate(@conversation)
    assert_kind_of Hash, result[:explanation]
    assert_includes [ true, false ], result[:explanation][:result]
    assert result[:explanation][:reason].present?
  end

  test "returns not complete when stage has no completion predicate" do
    stage = @conversation.current_stage
    stage.update!(completion: {})

    result = Reservi::FlowEvaluator.evaluate(@conversation)
    refute result[:complete]
  end

  test "handles compound completion predicate" do
    stage = @conversation.current_stage
    stage.update!(completion: {
      "all" => [
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "budget" } },
        { "exists" => { "kind" => "field", "scope" => "conversation", "key" => "urgency" } }
      ]
    })

    @conversation.update!(custom_values: { "budget" => 500, "urgency" => "high" })
    result = Reservi::FlowEvaluator.evaluate(@conversation)
    assert result[:complete]
    assert_equal "All conditions", result[:explanation][:reason]
  end
end
