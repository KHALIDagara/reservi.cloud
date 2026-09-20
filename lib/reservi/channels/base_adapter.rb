module Reservi
  module Channels
    # Base contract for channel adapters.
    #
    # Each adapter handles provider-specific send/receive/status contracts.
    # For T08, only the DevAdapter is implemented with deterministic fixtures.
    #
    # Subclasses implement:
    #   send_message(message_delivery:) -> { status:, provider_message_id:, error: }
    #   receive_webhook(params, channel:) -> parsed payload
    class BaseAdapter
      def self.for_provider(provider_type)
        case provider_type
        when "dev" then DevAdapter
        when "whatsapp" then WhatsappCloudAdapter
        when "instagram" then InstagramAdapter
        else raise ArgumentError, "Unknown provider_type: #{provider_type}"
        end.new
      end

      # Subclasses implement:
      #   send_message(message_delivery:) -> { status:, provider_message_id:, error: }
      def send_message(message_delivery:)
        raise NotImplementedError
      end
    end
  end
end
