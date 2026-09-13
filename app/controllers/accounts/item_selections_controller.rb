module Accounts
  class ItemSelectionsController < ApplicationController
    before_action :require_account_access!
    before_action :set_conversation

    def create
      item = current_account.items.find(item_selection_params[:item_id])
      ItemSelections::Select.call(
        conversation: @conversation,
        item: item,
        role_key: item_selection_params[:role_key],
        actor_membership: current_membership
      )
      redirect_to account_conversation_path(current_account, @conversation), notice: "Item selected."
    rescue ActiveRecord::RecordNotFound
      redirect_to account_conversation_path(current_account, @conversation), alert: "Item not found."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def destroy
      selection = @conversation.item_selections.find(params[:id])
      selection.destroy!
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
  end
end