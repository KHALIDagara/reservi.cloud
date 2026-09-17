module ItemSelections
  module Clear
    module_function

    def call(conversation:, role_key:, expected_selection_id:, actor_membership:)
      conversation.with_lock do
        current = conversation.item_selections.for_role(role_key).first
        return unless current

        if current.id != expected_selection_id.to_i
          raise Reservi::Errors::OperationError, "Selection changed. Refresh before clearing it."
        end

        current.destroy!
      end
    end
  end
end
