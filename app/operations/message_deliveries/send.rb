module MessageDeliveries
  # Creates a Message (local) and a MessageDelivery (outbound intent),
  # then enqueues a job to actually deliver via the channel adapter.
  #
  # Idempotent: the operation_key prevents duplicate intents for the same
  # logical send (INV-070).
  class Send
    def self.call(conversation:, channel:, agent:, message:, operation_key:)
      new(conversation:, channel:, agent:, message:, operation_key:).call
    end

    def initialize(conversation:, channel:, agent:, message:, operation_key:)
      @conversation = conversation
      @channel = channel
      @agent = agent
      @message = message
      @operation_key = operation_key
    end

    def call
      raise Reservi::Errors::OperationError, "Channel is not active." unless @channel.active?

      @conversation.transaction do
        # Check for duplicate operation_key (idempotency)
        existing = MessageDelivery.find_by(operation_key: @operation_key)
        return existing if existing

        # Use the canonical Message created by the caller (INV-010 — exactly one
        # Message per outbound send). Attachments are already attached to this
        # Message; the delivery intent references the same record.
        message = @message

        # Create the delivery intent
        delivery = @conversation.account.message_deliveries.create!(
          channel: @channel,
          message: message,
          status: "pending",
          operation_key: @operation_key
        )

        # Enqueue delivery job
        MessageDeliveryJob.perform_later(delivery.id)

        delivery
      end
    end
  end
end
