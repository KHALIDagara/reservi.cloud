module Notes
  # Adds an internal Note to a Conversation. Notes are never sent through
  # customer-facing channels (INV-016).
  class Create
    def self.call(conversation:, agent:, content:)
      new(conversation:, agent:, content:).call
    end

    def initialize(conversation:, agent:, content:)
      @conversation = conversation
      @agent = agent
      @content = content
    end

    def call
      @conversation.notes.create!(
        agent: @agent,
        content: @content
      )
    end
  end
end
