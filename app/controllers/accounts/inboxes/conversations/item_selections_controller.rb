module Accounts
  module Inboxes
    module Conversations
      # Item selection picker for a conversation within an inbox.
      # Renders a modal with items from the stage-configured catalog.
      class ItemSelectionsController < ApplicationController
        before_action :require_account_access!
        before_action :set_inbox
        before_action :set_conversation

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/item_selection?role_key=
        def show
          @role_key = params[:role_key]
          return head :not_found unless @role_key.present?

          stage = @conversation.current_stage
          catalog_block = stage&.blocks&.find { |b| b["type"] == "catalog" && b["role_key"] == @role_key }
          return head :not_found unless catalog_block

          catalog_key = catalog_block["catalog_key"]
          @catalog = current_account.catalogs.active
            .where("LOWER(title) = ?", catalog_key.downcase)
            .includes(:items)
            .first
          return head :not_found unless @catalog

          @current_selection = @conversation.item_selections.find_by(role_key: @role_key)

          render layout: false
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/item_selection
        def create
          role_key = params[:role_key]
          item_id = params[:item_id].to_i

          stage = @conversation.current_stage
          catalog_block = stage&.blocks&.find { |b| b["type"] == "catalog" && b["role_key"] == role_key }
          return head :not_found unless catalog_block

          item = Item.find_by(id: item_id, account_id: current_account.id)
          return head :not_found unless item

          ItemSelections::Select.call(
            conversation: @conversation,
            item:,
            role_key:,
            actor_membership: current_membership
          )

          Flows::Evaluate.call(conversation: @conversation)

          @conversation.reload
          publish_conversation_changed(@conversation, :item_selected)

          render turbo_stream: [
            turbo_stream.replace("conversation_panel", partial: "accounts/inboxes/conversations/panel/show",
              locals: rebuild_panel_locals),
            turbo_stream.update("conversation_modal", ""),
            turbo_stream.action(:dispatch_event, "modal:close", { bubbles: true, cancelable: false })
          ]
        rescue Reservi::Errors::OperationError => e
          render turbo_stream: turbo_stream.replace("conversation_modal",
            partial: "accounts/inboxes/conversations/panel/edit_field_error",
            locals: { error: e.message })
        end

        # DELETE /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/item_selection?role_key=
        def destroy
          role_key = params[:role_key]
          selection = @conversation.item_selections.find_by(role_key:)
          return head :not_found unless selection

          ItemSelections::Clear.call(
            item_selection: selection,
            actor_membership: current_membership
          )

          Flows::Evaluate.call(conversation: @conversation)

          @conversation.reload
          publish_conversation_changed(@conversation, :item_selected)

          render turbo_stream: [
            turbo_stream.replace("conversation_panel", partial: "accounts/inboxes/conversations/panel/show",
              locals: rebuild_panel_locals),
            turbo_stream.update("conversation_modal", ""),
            turbo_stream.action(:dispatch_event, "modal:close", { bubbles: true, cancelable: false })
          ]
        rescue Reservi::Errors::OperationError => e
          render turbo_stream: turbo_stream.replace("conversation_modal",
            partial: "accounts/inboxes/conversations/panel/edit_field_error",
            locals: { error: e.message })
        end

        private

        def set_inbox
          @inbox = current_account.channels.find(params[:inbox_id])
        end

        def set_conversation
          @conversation = @inbox.conversations.find(params[:conversation_id])
        rescue ActiveRecord::RecordNotFound
          redirect_to account_inbox_path(current_account), alert: "Conversation not found."
        end

        def publish_conversation_changed(conversation, event)
          return unless conversation&.persisted?
          Realtime::ConversationChangedJob.perform_later(
            account_id:      conversation.account_id,
            conversation_id: conversation.id,
            revision:        conversation.revision,
            event:
          )
        end

        def rebuild_panel_locals
          @conversation.reload
          stage = @conversation.current_stage
          stage_blocks = stage&.blocks || []
          loader = ::Realtime::ConversationChangedJob::AccountPanelLoader.new(@conversation)
          loader.call
        end
      end
    end
  end
end