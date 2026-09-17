require "net/http"
require "json"

module Reservi
  module Channels
    # WhatsApp Cloud API adapter (Meta Graph API).
    #
    # Sends text messages via POST /{phone-number-id}/messages.
    # Normalizes inbound webhook payloads from the Meta webhook structure.
    class WhatsappCloudAdapter < BaseAdapter
      API_BASE = "https://graph.facebook.com/v22.0".freeze

      def send_message(delivery:)
        config = delivery.channel.provider_config
        phone_number_id = config["phone_number_id"]
        access_token = delivery.channel.credential("access_token")

        payload = {
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: delivery.message.conversation.channel_threads
               .find_by(channel: delivery.channel)&.external_contact_id,
          type: "text",
          text: { body: delivery.message.content }
        }

        response = post_json("#{API_BASE}/#{phone_number_id}/messages", payload, access_token)
        parsed = JSON.parse(response.body)

        if response.code.to_i == 200 || response.code.to_i == 201
          { status: "sent", provider_message_id: parsed.dig("messages", 0, "id") }
        else
          error = parsed.dig("error", "message") || "Unknown error"
          { status: "failed", error: error }
        end
      rescue => e
        { status: "failed", error: e.message }
      end

      # Normalize an inbound WhatsApp webhook payload into our domain format.
      def self.normalize_payload(webhook_body)
        entry = webhook_body.dig("entry", 0)
        return nil unless entry

        change = entry.dig("changes", 0)
        return nil unless change

        value = change["value"]
        return nil unless value

        messages = value["messages"]
        contacts = value["contacts"]

        # Status updates (delivery callbacks)
        if value["statuses"]
          status = value["statuses"].first
          return {
            type: "message_status",
            provider_message_id: status["id"],
            status: status["status"], # sent, delivered, read, failed
            recipient_id: status["recipient_id"],
            timestamp: status["timestamp"]
          }
        end

        # Inbound message
        if messages && messages.any?
          msg = messages.first
          contact = contacts&.first
          return {
            type: "message",
            provider_message_id: msg["id"],
            from: msg["from"],
            contact_name: contact&.dig("profile", "name"),
            body: msg.dig("text", "body") || msg.dig("button", "text"),
            media_type: msg["type"],
            timestamp: msg["timestamp"]
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
