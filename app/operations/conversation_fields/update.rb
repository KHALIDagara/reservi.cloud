module ConversationFields
  class Update
    def self.call(conversation:, actor_membership:, attributes:)
      new(conversation:, actor_membership:, attributes:).call
    end

    def initialize(conversation:, actor_membership:, attributes:)
      @conversation = conversation
      @actor_membership = actor_membership
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      definitions = @conversation.account.field_definitions.active.for_conversation
      custom = @attributes.transform_keys(&:to_s)

      validation = FieldValueValidator.validate_values(custom, definitions)
      unless validation[:valid]
        raise Reservi::Errors::OperationError, validation[:errors].to_s
      end

      @conversation.with_lock do
        @conversation.update!(custom_values: @conversation.custom_values.merge(custom))
        @conversation
      end.tap do
        # Re-evaluate rules after field change — predicates may now match
        @conversation.reload
        Flows::Evaluate.call(conversation: @conversation)
      end
    rescue => e
      Rails.logger.warn "Rule evaluation after field update failed: #{e.message}"
      raise
    end
  end
end
