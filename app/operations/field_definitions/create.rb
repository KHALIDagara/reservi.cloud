module FieldDefinitions
  class Create
    def self.call(account:, actor_membership:, attributes:)
      new(account:, actor_membership:, attributes:).call
    end

    def initialize(account:, actor_membership:, attributes:)
      @account = account
      @actor_membership = actor_membership
      @attributes = attributes
    end

    def call
      raise Reservi::Errors::AuthorizationError, "Only administrators can manage field definitions." unless admin?
      raise Reservi::Errors::OperationError, "Key cannot shadow a built-in binding." if reserved_key?

      @account.field_definitions.create!(@attributes)
    end

    private

    def admin?
      Accounts::Policy.new(@actor_membership).admin?
    end

    def reserved_key?
      key = @attributes[:key].to_s.strip.downcase
      %w[name phone email_address locale].include?(key)
    end
  end
end
