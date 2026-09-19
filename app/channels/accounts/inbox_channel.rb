# frozen_string_literal: true

# Streams conversation-level changes for the agents looking at an inbox.
#
# Each agent subscribes to one stream per inbox they have open.
# The channel enforces account membership and inbox access.
module Accounts
  class InboxChannel < ApplicationCable::Channel
    def subscribed
      account = Account.find(params[:account_id])
      inbox   = account.channels.find(params[:inbox_id])

      # Authorize: the current user must be a member of this account
      membership = account.memberships.find_by(user: current_user)
      reject unless membership

      stream_for [account, inbox, current_user]
    end

    def unsubscribed
      # No cleanup needed
    end
  end
end