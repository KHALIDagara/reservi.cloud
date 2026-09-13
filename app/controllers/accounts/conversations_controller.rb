module Accounts
  class ConversationsController < ApplicationController
    before_action :require_account_access!
    before_action :set_conversation, only: %i[show create_message create_note claim unclaim cancel]
    PAGE_SIZE = 50

    def index
      redirect_to account_inbox_path(current_account)
    end

    def show
      @messages = @conversation.messages.chronological.includes(:agent)
      @notes = @conversation.notes.chronological.includes(:agent)
      touch_read_cursor!
    end

    def new
      @customers = current_account.customers.order(:name).limit(100)
      @conversation = current_account.conversations.new
    end

    def create
      agent = current_membership.agent
      conversation = Conversations::Create.call(
        account: current_account,
        customer_attributes: customer_params,
        agent:,
        content: conversation_params[:initial_message],
        team_id: agent.teams.first&.id
      )
      redirect_to account_conversation_path(current_account, conversation), notice: "Conversation created."
    rescue Reservi::Errors::OperationError => e
      redirect_to new_account_conversation_path(current_account), alert: e.message
    end

    def create_message
      message = Messages::Create.call(
        conversation: @conversation,
        agent: current_membership.agent,
        content: params[:message][:content],
        direction: "outbound"
      )
      redirect_to account_conversation_path(current_account, @conversation)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def create_note
      note = Notes::Create.call(
        conversation: @conversation,
        agent: current_membership.agent,
        content: params[:note][:content]
      )
      redirect_to account_conversation_path(current_account, @conversation)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def claim
      Conversations::Claim.call(conversation: @conversation, agent: current_membership.agent)
      redirect_to account_conversation_path(current_account, @conversation), notice: "Conversation claimed."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_inbox_path(current_account), alert: e.message
    end

    def unclaim
      Conversations::Unclaim.call(conversation: @conversation, agent: current_membership.agent)
      redirect_to account_inbox_path(current_account), notice: "Conversation released."
    rescue Reservi::Errors::AuthorizationError, Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    def cancel
      Conversations::Cancel.call(
        conversation: @conversation,
        agent: current_membership.agent,
        reason: params[:reason]
      )
      redirect_to account_inbox_path(current_account), notice: "Conversation cancelled."
    rescue Reservi::Errors::OperationError => e
      redirect_to account_conversation_path(current_account, @conversation), alert: e.message
    end

    private

    def set_conversation
      @conversation = current_account.conversations.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to account_inbox_path(current_account), alert: "Conversation not found."
    end

    def touch_read_cursor!
      read = @conversation.conversation_reads.find_or_initialize_by(agent: current_membership.agent)
      last_message = @conversation.messages.order(id: :desc).first
      if last_message && (read.new_record? || read.last_read_message_id.to_i < last_message.id)
        read.update!(last_read_message_id: last_message.id)
      end
    end

    def customer_params
      params.require(:conversation).permit(:name, :email_address, :phone).to_h.symbolize_keys
    end

    def conversation_params
      params.require(:conversation).permit(:initial_message)
    end
  end
end