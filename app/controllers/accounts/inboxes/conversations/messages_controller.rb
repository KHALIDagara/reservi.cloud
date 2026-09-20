module Accounts
  module Inboxes
    module Conversations
      class MessagesController < ApplicationController
        before_action :require_account_access!
        before_action :set_inbox
        before_action :set_conversation

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/messages
        #
        # Supports windowed loading:
        #   ?before=ID   – load messages before the given ID (older messages)
        #   ?after=ID    – load messages after the given ID (reconnect)
        #   (default)    – latest 30 messages
        def index
          mode = if params[:before].present?
                   :before
                 elsif params[:after].present?
                   :after
                 else
                   :latest
                 end

          cursor_id = params[:before] || params[:after]

          @messages = ::Messages::WindowQuery.call(
            conversation: @conversation,
            mode:,
            cursor_id:,
            limit: 30
          )

          # For the "load older" response, we use a dedicated partial
          # that only renders the message list (no layout).
          if params[:before].present?
            render partial: "accounts/inboxes/conversations/messages/messages_list",
                   locals: { messages: @messages },
                   layout: false
          else
            # Default: redirect to conversation show (this is the initial load path)
            render plain: "", status: :no_content and return unless request.format.html?
            redirect_to inbox_conversation_url(current_account, params[:inbox_id], @conversation)
          end
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/messages
        def create
          ::Conversations::SendMessage.call(
            conversation: @conversation,
            agent:        current_membership.agent,
            content:      params[:content],
            attachments:  Array(params[:attachments])
          )
          redirect_to conversation_return_path, notice: "Message sent."
        rescue ActiveRecord::RecordInvalid, Reservi::Errors::OperationError => e
          redirect_to conversation_return_path, alert: e.message
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

        def conversation_return_path
          inbox_conversation_url(current_account, params[:inbox_id], @conversation)
        end
      end
    end
  end
end