module CustomerFields
  # Updates Customer profile fields (both canonical columns and custom_values).
  # Canonical columns: name, phone, email_address, locale.
  # Custom values: keys matching customer-scoped FieldDefinitions.
  # Increments profile_revision for fan-out (T03+).
  class Update
    def self.call(customer:, actor_membership:, attributes:)
      new(customer:, actor_membership:, attributes:).call
    end

    def initialize(customer:, actor_membership:, attributes:)
      @customer = customer
      @actor_membership = actor_membership
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      @customer.account.field_definitions.active.for_customer

      # Separate built-in bindings from custom values
      built_in = {}
      custom = {}

      @attributes.each do |key, value|
        if %w[name phone email_address locale].include?(key.to_s)
          built_in[key] = value
        else
          custom[key] = value
        end
      end

      # Validate custom values
      definitions = @customer.account.field_definitions.active.for_customer
      validation = FieldValueValidator.validate_values(custom.transform_keys(&:to_s), definitions)
      unless validation[:valid]
        raise Reservi::Errors::OperationError, validation[:errors].to_s
      end

      @customer.with_lock do
        @customer.update!(**built_in, custom_values: @customer.custom_values.merge(custom.stringify_keys))
        @customer.increment!(:profile_revision)
        @customer
      end
    end
  end
end