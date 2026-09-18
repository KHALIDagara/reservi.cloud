require "net/http"
require "json"
require "cgi"

module Reservi
  module Channels
    class OauthClient
      GRAPH_VERSION = ENV.fetch("META_GRAPH_VERSION", "v22.0")
      GRAPH_BASE = "https://graph.facebook.com/#{GRAPH_VERSION}".freeze
      INSTAGRAM_GRAPH_BASE = "https://graph.instagram.com/#{GRAPH_VERSION}".freeze

      class ProviderError < Reservi::Errors::OperationError; end

      def self.configured?(provider)
        case provider.to_s
        when "whatsapp"
          ENV["WHATSAPP_APP_ID"].present? && ENV["WHATSAPP_APP_SECRET"].present? &&
            ENV["WHATSAPP_CONFIGURATION_ID"].present?
        when "instagram"
          ENV["INSTAGRAM_APP_ID"].present? && ENV["INSTAGRAM_APP_SECRET"].present?
        else false
        end
      end

      def self.public_config(provider)
        return {} unless provider.to_s == "whatsapp"

        {
          app_id: ENV["WHATSAPP_APP_ID"],
          configuration_id: ENV["WHATSAPP_CONFIGURATION_ID"],
          api_version: ENV.fetch("META_GRAPH_VERSION", "v22.0")
        }
      end

      def initialize(provider)
        @provider = provider.to_s
        raise ProviderError, "Unsupported inbox provider." unless %w[whatsapp instagram].include?(@provider)
        raise ProviderError, "#{@provider.titleize} OAuth is not configured." unless self.class.configured?(@provider)
      end

      def authorization_url(redirect_uri:, state:)
        raise ProviderError, "WhatsApp uses Embedded Signup." unless @provider == "instagram"

        query = URI.encode_www_form(
          client_id: instagram_app_id,
          redirect_uri:,
          response_type: "code",
          scope: "instagram_business_basic,instagram_business_manage_messages",
          state:
        )
        "https://www.instagram.com/oauth/authorize?#{query}"
      end

      def connect_instagram(code:, redirect_uri:)
        short = request_json(
          :post,
          "https://api.instagram.com/oauth/access_token",
          form: { client_id: instagram_app_id, client_secret: instagram_app_secret,
                  grant_type: "authorization_code", redirect_uri:, code: }
        )
        short_token = short.fetch("access_token")
        long = request_json(
          :get,
          "#{INSTAGRAM_GRAPH_BASE}/access_token",
          query: { grant_type: "ig_exchange_token", client_secret: instagram_app_secret,
                   access_token: short_token }
        )
        access_token = long.fetch("access_token")
        profile = request_json(
          :get,
          "#{INSTAGRAM_GRAPH_BASE}/me",
          query: { fields: "id,user_id,username,account_type", access_token: }
        )
        instagram_id = (profile["user_id"] || profile["id"]).to_s
        request_json(
          :post,
          "#{INSTAGRAM_GRAPH_BASE}/#{escape_path(instagram_id)}/subscribed_apps",
          form: {
            subscribed_fields: "messages,messaging_postbacks,messaging_seen,message_reactions",
            access_token:
          }
        )

        {
          provider: "instagram",
          external_id: instagram_id,
          name: profile["username"].presence || "Instagram",
          provider_config: {
            "instagram_id" => instagram_id,
            "username" => profile["username"],
            "account_type" => profile["account_type"],
            "webhook_verify_token" => SecureRandom.urlsafe_base64(32)
          }.compact,
          credentials: {
            "access_token" => access_token,
            "token_expires_at" => long["expires_in"] ? long["expires_in"].to_i.seconds.from_now.iso8601 : nil
          }.compact
        }
      rescue KeyError
        raise ProviderError, "Instagram did not return the credentials required to connect this inbox."
      end

      def connect_whatsapp(code:, business_id:, waba_id:, phone_number_id:)
        token_response = request_json(
          :get,
          "#{GRAPH_BASE}/oauth/access_token",
          query: { client_id: whatsapp_app_id, client_secret: whatsapp_app_secret, code: }
        )
        access_token = token_response.fetch("access_token")
        phones = request_json(
          :get,
          "#{GRAPH_BASE}/#{escape_path(waba_id)}/phone_numbers",
          query: { fields: "id,display_phone_number,verified_name", access_token: }
        ).fetch("data", [])
        phone = phones.find { |candidate| candidate["id"].to_s == phone_number_id.to_s }
        raise ProviderError, "The selected WhatsApp number could not be verified." unless phone

        verify_token = SecureRandom.urlsafe_base64(32)

        # Step 1: Subscribe the app to the WABA
        request_json(
          :post,
          "#{GRAPH_BASE}/#{escape_path(waba_id)}/subscribed_apps",
          form: { access_token: }
        )

        # Step 2: Override callback URL with our verify token so Meta can
        # validate the webhook immediately — no manual console setup needed.
        callback_url = "#{webhook_base_url}/webhooks/meta/whatsapp"
        begin
          request_json(
            :post,
            "#{GRAPH_BASE}/#{escape_path(waba_id)}/subscribed_apps",
            form: {
              override_callback_uri: callback_url,
              verify_token: verify_token,
              subscribed_fields: "messages",
              access_token: access_token
            }
          )
        rescue ProviderError => e
          Rails.logger.warn("[WHATSAPP] Webhook callback override non-fatal: #{e.message}")
        end

        {
          provider: "whatsapp",
          external_id: phone_number_id.to_s,
          name: phone["verified_name"].presence || phone["display_phone_number"].presence || "WhatsApp",
          provider_config: {
            "business_id" => business_id.to_s,
            "waba_id" => waba_id.to_s,
            "phone_number_id" => phone_number_id.to_s,
            "display_phone_number" => phone["display_phone_number"],
            "verified_name" => phone["verified_name"],
            "webhook_verify_token" => verify_token
          }.compact,
          credentials: {
            "access_token" => access_token
          }
        }
      rescue KeyError
        raise ProviderError, "WhatsApp did not return the credentials required to connect this inbox."
      end

      private

      def request_json(method, url, query: nil, form: nil)
        uri = URI(url)
        uri.query = URI.encode_www_form(query) if query
        request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
        request.set_form_data(form) if form

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          http.request(request)
        end
        parsed = JSON.parse(response.body.presence || "{}")
        return parsed if response.is_a?(Net::HTTPSuccess)

        raise ProviderError, parsed.dig("error", "message") || "#{@provider.titleize} connection failed."
      rescue JSON::ParserError, SocketError, Timeout::Error, Errno::ECONNREFUSED => e
        raise ProviderError, "#{@provider.titleize} connection failed: #{e.message}"
      end

      def escape_path(value)
        CGI.escapeURIComponent(value.to_s)
      end

      def whatsapp_app_id = ENV.fetch("WHATSAPP_APP_ID")
      def whatsapp_app_secret = ENV.fetch("WHATSAPP_APP_SECRET")
      def instagram_app_id = ENV.fetch("INSTAGRAM_APP_ID")
      def instagram_app_secret = ENV.fetch("INSTAGRAM_APP_SECRET")

      def webhook_base_url
        ENV.fetch("WEBHOOK_BASE_URL", "https://reservi.cloud")
      end
    end
  end
end
