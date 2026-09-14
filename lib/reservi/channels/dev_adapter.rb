module Reservi
  module Channels
    # Deterministic development channel adapter.
    #
    # Does not contact any external provider. Records deliveries in the
    # message_deliveries table with predictable results based on message content.
    #
    # Simulates:
    #   - Successful send: content that does not match failure patterns
    #   - Simulated failure: content containing "SIMULATE_FAILURE"
    #   - Simulated timeout: content containing "SIMULATE_TIMEOUT"
    #
    # Inbound webhooks are received via the webhook controller, authenticated
    # by the channel's inbound_token, and create Messages directly.
    class DevAdapter
      def self.send_message(message_delivery:)
        new(message_delivery:).send_message
      end

      def initialize(message_delivery:)
        @message_delivery = message_delivery
        @message = message_delivery.message
      end

      def send_message
        content = @message.content.to_s

        if content.include?("SIMULATE_FAILURE")
          simulate_failure
        elsif content.include?("SIMULATE_TIMEOUT")
          simulate_timeout
        else
          simulate_success
        end
      end

      private

      def simulate_success
        {
          status: "sent",
          provider_message_id: "dev_msg_#{@message.id}_#{Time.current.to_i}",
          error: nil
        }
      end

      def simulate_failure
        {
          status: "failed",
          provider_message_id: nil,
          error: "Simulated delivery failure"
        }
      end

      def simulate_timeout
        {
          status: "unknown",
          provider_message_id: "dev_msg_#{@message.id}_#{Time.current.to_i}",
          error: "Simulated timeout — provider accepted but no callback received"
        }
      end
    end
  end
end