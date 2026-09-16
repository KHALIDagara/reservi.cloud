require "test_helper"

class Reservi::Ai::FakeAdapterTest < ActiveSupport::TestCase
  test "returns default response for unknown prompt" do
    adapter = Reservi::Ai::FakeAdapter.new
    result = adapter.generate(
      prompt: "Hello world",
      system_message: "You are a helpful assistant",
      tools: nil
    )

    assert_equal "This is a fake AI response. I understand the request.", result["content"]
    assert_equal [], result["tool_calls"]
    assert_equal 50, result.dig("usage", "prompt_tokens")
    assert_equal 20, result.dig("usage", "completion_tokens")
    assert_equal 70, result.dig("usage", "total_tokens")
  end

  test "returns configured response when system_message key matches" do
    custom = {
      "content" => "Custom response",
      "tool_calls" => [],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { "system_key" => custom })
    result = adapter.generate(
      prompt: "Hello",
      system_message: "system_key",
      tools: nil
    )

    assert_equal "Custom response", result["content"]
    assert_equal 15, result.dig("usage", "total_tokens")
  end

  test "returns configured response when prompt key matches" do
    custom = {
      "content" => "Prompt match",
      "tool_calls" => [ { "name" => "read_workspace", "arguments" => {} } ],
      "usage" => { "prompt_tokens" => 5, "completion_tokens" => 3, "total_tokens" => 8 }
    }

    adapter = Reservi::Ai::FakeAdapter.new(responses: { "exact prompt" => custom })
    result = adapter.generate(
      prompt: "exact prompt",
      system_message: "something else",
      tools: nil
    )

    assert_equal "Prompt match", result["content"]
    assert_equal 1, result["tool_calls"].length
    assert_equal "read_workspace", result["tool_calls"].first["name"]
  end

  test "prefers system_message match over prompt match" do
    system_response = { "content" => "System match", "tool_calls" => [], "usage" => {} }
    prompt_response = { "content" => "Prompt match", "tool_calls" => [], "usage" => {} }

    adapter = Reservi::Ai::FakeAdapter.new(
      responses: { "sys" => system_response, "p" => prompt_response }
    )
    result = adapter.generate(
      prompt: "p",
      system_message: "sys",
      tools: nil
    )

    assert_equal "System match", result["content"]
  end

  test "tracks all calls in @calls array" do
    adapter = Reservi::Ai::FakeAdapter.new

    adapter.generate(prompt: "First", system_message: "msg1", tools: nil)
    adapter.generate(prompt: "Second", system_message: "msg2", tools: [ "tool_a" ])
    adapter.generate(prompt: "Third", system_message: "msg3", tools: [ "tool_b" ])

    assert_equal 3, adapter.calls.size
    assert_equal "First", adapter.calls[0][:prompt]
    assert_equal "msg1", adapter.calls[0][:system_message]
    assert_nil adapter.calls[0][:tools]

    assert_equal "Second", adapter.calls[1][:prompt]
    assert_equal [ "tool_a" ], adapter.calls[1][:tools]

    assert_equal "Third", adapter.calls[2][:prompt]
    assert_equal [ "tool_b" ], adapter.calls[2][:tools]
  end

  test "each call records tools even when nil" do
    adapter = Reservi::Ai::FakeAdapter.new
    adapter.generate(prompt: "x", system_message: "y", tools: nil)
    adapter.generate(prompt: "x2", system_message: "y2", tools: [ "some_tool" ])

    assert_nil adapter.calls[0][:tools]
    assert_equal [ "some_tool" ], adapter.calls[1][:tools]
  end
end
