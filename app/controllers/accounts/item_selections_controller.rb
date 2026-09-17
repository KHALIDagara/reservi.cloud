module Accounts
  class ItemSelectionsController < ApplicationController
    before_action :require_account_access!
    before_action :set_conversation

    def create
      item = current_account.items.find(item_selection_params[:item_id])
      validate_catalog_role!(role_key: item_selection_params[:role_key], item:)
      ItemSelections::Select.call(
        conversation: @conversation,
        item: item,
        role_key: item_selection_params[:role_key],
        actor_membership: current_membership
      )
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Item selected."
    rescue ActiveRecord::RecordNotFound
      redirect_to account_conversation_path(current_account, @conversation), alert: "Item not found."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def destroy
      selection = @conversation.item_selections.find(params[:id])
      validate_catalog_role!(role_key: selection.role_key, item: selection.item)
      ItemSelections::Clear.call(
        conversation: @conversation,
        role_key: selection.role_key,
        expected_selection_id: selection.id,
        actor_membership: current_membership
      )
      Flows::Evaluate.call(conversation: @conversation)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Selection cleared."
    end

    private

    def set_conversation
      @conversation = current_account.conversations.find(params[:conversation_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to account_inbox_path(current_account), alert: "Conversation not found."
    end

    def item_selection_params
      params.require(:item_selection).permit(:item_id, :role_key)
    end

    def validate_catalog_role!(role_key:, item:)
      block = Array(@conversation.current_stage&.blocks).find do |candidate|
        candidate["type"] == "catalog" && candidate["role_key"] == role_key
      end
      unless block
        raise Reservi::Errors::OperationError, "That item selector is not available in the current stage."
      end

      configured_catalog = current_account.catalogs.active
        .where("LOWER(title) = ?", block["catalog_key"].to_s.downcase)
        .first
      unless configured_catalog&.id == item.catalog_id
        raise Reservi::Errors::OperationError, "That item does not belong to the configured catalog."
      end
    end
  end
end
