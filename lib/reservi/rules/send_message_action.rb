module Reservi
  module Rules
    # Sends a Message via a configured Channel from a Rule action.
    #
    # Config:
    #   { "type" => "send_message",
    #     "content" => "Your request has been received.",
    #     "channel_id" => 1 }
    #
    # Uses MessageDeliveries::Send which creates a local message +
    # durable delivery intent + enqueues async sending.
    class SendMessageAction
      def self.call(action_config, conversation:, context:)
        new(action_config, conversation:, context:).call
      end

      def initialize(action_config, conversation:, context:)
        @action_config = action_config
        @conversation = conversation
        @context = context
      end

      def call
        content = @action_config["content"]
        return { type: "send_message", status: "failed", error: "Missing content" } unless content

        channel_id = @action_config["channel_id"]
        channel = @conversation.account.channels.active.find_by(id: channel_id) if channel_id

        unless channel
          return { type: "send_message", status: "failed", error: "No active channel configured" }
        end

        # Use a deterministic operation_key for idempotency.
        # SHA256 is stable across Ruby restarts (unlike String#hash).
        content_digest = Digest::SHA256.hexdigest(content)
        operation_key = "rule_send_#{@conversation.id}_#{@conversation.updated_at.to_i}_#{content_digest}"

        # Find a human agent to attribute the message to, or use a system agent
        agent = @conversation.owner || @conversation.account.agents.active.human.first

        # Create the canonical Message first (INV-010 — exactly one per send)
        message = Messages::Create.call(
          conversation: @conversation,
          agent: agent,
          content: content,
          direction: "outbound"
        )

        delivery = MessageDeliveries::Send.call(
          conversation: @conversation,
          channel: channel,
          agent: agent,
          message: message,
          operation_key: operation_key
        )

        { type: "send_message", status: "queued", delivery_id: delivery.id,
          message_id: delivery.message_id }
      rescue Reservi::Errors::OperationError => e
        { type: "send_message", status: "failed", error: e.message }
      end
    end
  end
end
