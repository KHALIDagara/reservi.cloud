module Messages
  # Adds a Message to a Conversation. Handles both inbound (from Customer) and
  # outbound (from an Agent). Touches the conversation for inbox ordering.
  class Create
    def self.call(conversation:, agent:, content:, direction: "outbound")
      new(conversation:, agent:, content:, direction:).call
    end

    def initialize(conversation:, agent:, content:, direction:)
      @conversation = conversation
      @agent = agent
      @content = content
      @direction = direction
    end

    def call
      @conversation.transaction do
        message = @conversation.messages.create!(
          agent: @agent,
          author_name: @agent.name,
          content: @content,
          direction: @direction,
          delivery_status: "local"
        )
        @conversation.update!(last_activity_at: Time.current)
        message
      end
    end
  end
end