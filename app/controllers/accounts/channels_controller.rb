module Accounts
  class ChannelsController < ApplicationController
    SUPPORTED_PROVIDERS = %w[whatsapp instagram].freeze

    before_action :require_account_access!
    before_action :require_admin!
    before_action :set_channel, only: %i[show destroy]

    def index
      @channels = current_account.channels.order(active: :desc, name: :asc)
    end

    def show
    end

    def new
    end

    def setup
      @provider = params[:provider].to_s
      raise ActionController::RoutingError, "Not Found" unless SUPPORTED_PROVIDERS.include?(@provider)

      @oauth_configured = Reservi::Channels::OauthClient.configured?(@provider)
      @public_config = Reservi::Channels::OauthClient.public_config(@provider)
    end

    def authorize
      provider = params[:provider].to_s
      raise ActionController::RoutingError, "Not Found" unless provider == "instagram"

      nonce = SecureRandom.urlsafe_base64(24)
      oauth_nonces[nonce] = Time.current.to_i
      state = oauth_verifier.generate(
        { account_id: current_account.id, user_id: Current.user.id, provider:, nonce: },
        expires_in: 10.minutes
      )
      redirect_to Reservi::Channels::OauthClient.new(provider).authorization_url(
        redirect_uri: channel_oauth_callback_url(provider:),
        state:
      ), allow_other_host: true
    rescue Reservi::Errors::OperationError => e
      redirect_to setup_account_inbox_path(current_account, provider:), alert: e.message
    end

    def complete_whatsapp
      unless whatsapp_params.values_at(:code, :business_id, :waba_id, :phone_number_id).all?(&:present?) &&
          whatsapp_params.values_at(:business_id, :waba_id, :phone_number_id).all? { |value| value.match?(/\A\d+\z/) }
        raise ActionController::ParameterMissing, :whatsapp_signup
      end

      oauth_client = Reservi::Channels::OauthClient.new("whatsapp")

      # Phase 1: Authenticate and build connection hash (no Meta API calls
      # that trigger webhook verification yet).
      connection = oauth_client.connect_whatsapp(
        code: whatsapp_params.fetch(:code),
        business_id: whatsapp_params.fetch(:business_id),
        waba_id: whatsapp_params.fetch(:waba_id),
        phone_number_id: whatsapp_params.fetch(:phone_number_id)
      )

      # Persist the channel FIRST so Meta's verification callback can find
      # it by phone number.
      channel = Channels::Connect.call(account: current_account, connection:)

      # Phase 2: Now that the channel exists, register the webhook. Meta
      # will immediately verify the callback URL and find the channel.
      begin
        oauth_client.subscribe_whatsapp_webhook(channel)
      rescue Reservi::Channels::OauthClient::ProviderError => e
        Rails.logger.warn("[WHATSAPP] Webhook subscription failed for channel #{channel.id}: #{e.message}")
        # Channel was created but webhook is broken — surface this to the user.
        render json: {
          warning: "WhatsApp inbox created, but webhook registration failed. Messages may not be received until this is resolved: #{e.message}",
          redirect_url: inbox_path(current_account, channel)
        }, status: :created
        return
      end

      render json: { redirect_url: inbox_path(current_account, channel) }, status: :created
    rescue ActionController::ParameterMissing, KeyError => e
      render json: { error: "WhatsApp returned incomplete signup details." }, status: :unprocessable_content
    rescue Reservi::Errors::OperationError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def set_channel
      @channel = current_account.channels.find(params[:id])
    end

    def require_admin!
      return if Accounts::Policy.new(current_membership).admin?

      raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage inboxes."
    end

    def whatsapp_params
      params.permit(:code, :business_id, :waba_id, :phone_number_id)
    end

    def oauth_verifier
      Rails.application.message_verifier("channel_oauth")
    end

    def oauth_nonces
      session[:channel_oauth_nonces] ||= {}
      session[:channel_oauth_nonces].delete_if { |_nonce, created_at| created_at.to_i < 15.minutes.ago.to_i }
    end
  end
end
