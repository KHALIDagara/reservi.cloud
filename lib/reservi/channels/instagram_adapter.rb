require "net/http"
require "json"

module Reservi
  module Channels
    # Instagram Messaging API adapter (Meta Graph API).
    #
    # Uses the Instagram Graph API (not Facebook Graph) for sending messages.
    # Normalizes inbound Instagram webhook payloads.
    class InstagramAdapter < BaseAdapter
      API_BASE = "https://graph.facebook.com/v22.0".freeze

      def send_message(message_delivery:)
        delivery = message_delivery
        config = delivery.channel.provider_config
        instagram_id = config["instagram_id"]
        access_token = delivery.channel.credential("access_token")

        payload = {
          recipient: {
            id: delivery.message.conversation.channel_threads
                 .find_by(channel: delivery.channel)&.external_contact_id
          },
          message: { text: delivery.message.content }
        }

        response = post_json("#{API_BASE}/#{instagram_id}/messages", payload, access_token)
        parsed = JSON.parse(response.body)

        if response.code.to_i == 200 || response.code.to_i == 201
          { status: "sent", provider_message_id: parsed["message_id"] }
        else
          error = parsed.dig("error", "message") || "Unknown error"
          { status: "failed", error: error }
        end
      rescue => e
        { status: "failed", error: e.message }
      end

      # Normalize an inbound Instagram webhook payload into our domain format.
      def self.normalize_payload(webhook_body)
        # Instagram webhooks come as an array of entries
        entries = webhook_body.is_a?(Array) ? webhook_body : [ webhook_body ]
        messaging = entries.first&.dig("messaging", 0)
        return nil unless messaging

        message = messaging["message"]
        sender = messaging["sender"]

        if message
          return {
            type: "message",
            provider_message_id: message["mid"],
            from: sender["id"],
            body: message["text"],
            timestamp: messaging["timestamp"]
          }
        end

        # Read receipts
        if messaging["read"]
          return {
            type: "message_status",
            provider_message_id: messaging.dig("read", "mid"),
            status: "read",
            timestamp: messaging["timestamp"]
          }
        end

        nil
      end

      private

      def post_json(url, body, access_token)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{access_token}"
        request["Content-Type"] = "application/json"
        request.body = body.to_json

        http.request(request)
      end
    end
  end
end
