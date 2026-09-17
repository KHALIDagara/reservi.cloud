module Channels
  class Connect
    EXTERNAL_ID_KEYS = {
      "whatsapp" => "phone_number_id",
      "instagram" => "instagram_id"
    }.freeze

    def self.call(account:, connection:)
      new(account:, connection:).call
    end

    def initialize(account:, connection:)
      @account = account
      @connection = connection.deep_stringify_keys
    end

    def call
      provider = @connection.fetch("provider")
      EXTERNAL_ID_KEYS.fetch(provider)
      external_id = @connection.fetch("external_id").to_s

      @account.with_lock do
        channel = Channel.lock.find_by(provider_type: provider, provider_external_id: external_id)
        if channel && channel.account_id != @account.id
          raise Reservi::Errors::OperationError, "This provider inbox is already connected to another account."
        end
        channel ||= @account.channels.new(
          provider_type: provider,
          provider_external_id: external_id,
          inbound_token: SecureRandom.urlsafe_base64(32),
          rate_limit_per_minute: 10
        )
        channel.assign_attributes(
          name: unique_name(@connection.fetch("name"), channel),
          provider_config: @connection.fetch("provider_config"),
          credentials: @connection.fetch("credentials"),
          active: true
        )
        channel.save!
        channel
      end
    rescue ActiveRecord::RecordNotUnique
      raise Reservi::Errors::OperationError, "This provider inbox is already connected."
    rescue KeyError
      raise Reservi::Errors::OperationError, "The provider returned an incomplete inbox connection."
    end

    private

    def unique_name(base, channel)
      normalized = base.to_s.strip.presence || @connection.fetch("provider").titleize
      return normalized unless @account.channels.where.not(id: channel.id).exists?(name: normalized)

      "#{normalized} · #{@connection.fetch('external_id').to_s.last(6)}"
    end
  end
end
