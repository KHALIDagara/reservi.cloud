module ItemSelections
  # Adds an Item selection to a Conversation for a given role_key.
  # Replaces atomically under Conversation lock for single-select roles.
  # Duplicate, foreign-account, and archived items are rejected.
  class Select
    MAX_ITEMS_PER_ROLE = 20

    def self.call(conversation:, item:, role_key:, actor_membership:)
      new(conversation:, item:, role_key:, actor_membership:).call
    end

    def initialize(conversation:, item:, role_key:, actor_membership:)
      @conversation = conversation
      @item = item
      @role_key = role_key
      @actor_membership = actor_membership
    end

    def call
      validate!
      @conversation.with_lock do
        # For single-select (default), clear existing selections for this role
        @conversation.item_selections.for_role(@role_key).destroy_all

        snapshot = build_snapshot
        @conversation.item_selections.create!(
          account: @conversation.account,
          catalog: @item.catalog,
          item: @item,
          role_key: @role_key,
          snapshot: snapshot
        )
      end
    end

    private

    def validate!
      raise Reservi::Errors::OperationError, "Item is archived." if @item.archived?
      raise Reservi::Errors::OperationError, "Item belongs to a different account." if @item.account_id != @conversation.account_id
    end

    def build_snapshot
      {
        "title" => @item.title,
        "price" => @item.price&.to_s,
        "currency" => @item.currency,
        "unit" => @item.unit
      }
    end
  end
end
