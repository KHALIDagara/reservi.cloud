# frozen_string_literal: true

# Streams message-level changes for the currently-open conversation.
#
# When an agent opens a conversation, they subscribe to this channel.
# New messages, delivery status changes, and panel updates stream here.
module Accounts
  class ConversationChannel < ApplicationCable::Channel
    def subscribed
      account      = Account.find(params[:account_id])
      conversation = account.conversations.find(params[:conversation_id])

      # Authorize membership
      membership = account.memberships.find_by(user: current_user)
      reject unless membership

      stream_for [account, conversation, current_user]
    end

    def unsubscribed
      # No cleanup needed
    end
  end
end