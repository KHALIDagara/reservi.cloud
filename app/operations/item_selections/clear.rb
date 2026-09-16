module ItemSelections
  module Clear
    module_function

    def call(conversation:, role_key:, actor_membership:)
      conversation.item_selections.for_role(role_key).destroy_all
    end
  end
end
