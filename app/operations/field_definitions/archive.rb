module FieldDefinitions
  module Archive
    module_function

    def call(definition:, actor_membership:)
      policy = Accounts::Policy.new(actor_membership)
      raise Reservi::Errors::AuthorizationError, "Only administrators can archive field definitions." unless policy.admin?

      definition.update!(archived: true)
      definition
    end
  end
end
