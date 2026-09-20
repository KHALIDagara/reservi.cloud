module Accounts
  module Inboxes
    module Conversations
      # Inbox-scoped assignment actions: claim, unclaim, reassign, cancel.
      # Replaces the legacy Accounts::ConversationsController for these paths.
      class AssignmentsController < ApplicationController
        before_action :require_account_access!
        before_action :set_inbox
        before_action :set_conversation

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/assignment/claim
        def claim
          Conversations::Claim.call(conversation: @conversation, agent: current_membership.agent)
          publish_conversation_changed(@conversation, :assignment_changed)
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), notice: "Conversation claimed."
        rescue Reservi::Errors::OperationError => e
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), alert: e.message
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/assignment/unclaim
        def unclaim
          Conversations::Unclaim.call(conversation: @conversation, agent: current_membership.agent)
          publish_conversation_changed(@conversation, :assignment_changed)
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), notice: "Conversation released."
        rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), alert: e.message
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/assignment/reassign
        def reassign
          agent = current_account.agents.assignable.find_by(id: params[:agent_id])
          return redirect_to inbox_conversation_path(current_account, @inbox, @conversation), alert: "Agent not found" unless agent

          if @conversation.owner_id.present?
            Conversations::Unclaim.call(conversation: @conversation, agent: @conversation.owner)
          end
          Conversations::Claim.call(conversation: @conversation, agent:)

          if agent.kind == "ai" && agent.active_for_work?
            AiRuns::Admit.call(agent:, conversation: @conversation, trigger: "assigned")
          end

          publish_conversation_changed(@conversation, :assignment_changed)
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), notice: "Conversation assigned."
        rescue Reservi::Errors::OperationError => e
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), alert: e.message
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/assignment/cancel
        def cancel
          Conversations::Cancel.call(
            conversation: @conversation,
            agent: current_membership.agent,
            reason: params[:reason]
          )
          publish_conversation_changed(@conversation, :stage_advanced)
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), notice: "Conversation cancelled."
        rescue Reservi::Errors::OperationError => e
          redirect_to inbox_conversation_path(current_account, @inbox, @conversation), alert: e.message
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
      end
    end
  end
end