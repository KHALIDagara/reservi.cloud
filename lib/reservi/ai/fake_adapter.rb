module Reservi
  module Ai
    # Deterministic fake AI adapter for development and testing.
    #
    # Does not contact any external API. Returns configurable responses
    # based on prompt/system_message matching and records every call
    # for inspection.
    #
    # Usage in tests:
    #   adapter = FakeAdapter.new(responses: { "greeting" => custom_response })
    #   result = adapter.generate(prompt: "Hi", system_message: "greeting", tools: nil)
    #   assert_equal 1, adapter.calls.size
    class FakeAdapter
      attr_reader :calls

      def initialize(responses: {})
        @responses = responses
        @calls     = []
      end

      def generate(prompt:, system_message:, tools: nil, context: nil)
        @calls << { prompt: prompt, system_message: system_message, tools: tools }

        response = @responses[system_message.to_s] || @responses[prompt.to_s]
        return response if response

        {
          "content" => "This is a fake AI response. I understand the request.",
          "tool_calls" => [],
          "usage" => { "prompt_tokens" => 50, "completion_tokens" => 20, "total_tokens" => 70 }
        }
      end
    end
  end
end