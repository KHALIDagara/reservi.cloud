module Accounts
  # Index: lists all inboxes. Show: the actual inbox workspace where
  # agents read and reply to conversations arriving through this channel.
  #
  # Inbox configuration (default assignment, delete) remains here for now.
  # Technical settings (provider info, webhook URL) will move to a settings
  # page in a follow-up.
  class InboxesController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!, except: [ :index, :show ]
    before_action :set_inbox, only: [ :show, :update, :destroy ]

    def index
      @inboxes = current_account.channels.order(active: :desc, name: :asc)
    end

    # The inbox workspace — the three-column conversation screen.
    # Conversation list and individual conversation detail are loaded via
    # Turbo Frame lazy-load and nested routes, so this action renders the
    # stable shell.
    def show
    end

    def update
      if params[:channel][:default_assignment_type] == "agent"
        @inbox.update!(default_agent_id: params[:channel][:default_agent_id], default_team_id: nil)
      elsif params[:channel][:default_assignment_type] == "team"
        @inbox.update!(default_agent_id: nil, default_team_id: params[:channel][:default_team_id])
      elsif params[:channel][:default_assignment_type] == "none"
        @inbox.update!(default_agent_id: nil, default_team_id: nil)
      end

      redirect_to account_inbox_path(current_account, @inbox), notice: "Inbox updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to account_inbox_path(current_account, @inbox), alert: e.message
    end

    def destroy
      @inbox.destroy!
      redirect_to account_inboxes_path(current_account), notice: "Inbox deleted."
    end

    private

    def set_inbox
      @inbox = current_account.channels.find(params[:id])
    end

    def require_admin!
      return if Accounts::Policy.new(current_membership).admin?
      raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage inboxes."
    end
  end
end