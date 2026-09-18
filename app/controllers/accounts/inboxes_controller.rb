module Accounts
  # Lists and shows inboxes (backed by Channel records).
  # Inboxes are the places where customer conversations arrive:
  # WhatsApp numbers, Instagram accounts, etc.
  #
  # Channel model remains the persistence layer; this controller
  # presents the user-facing "Inbox" concept.
  class InboxesController < ApplicationController
    before_action :require_account_access!
    before_action :require_admin!, except: [ :index, :show ]
    before_action :set_inbox, only: [ :show, :destroy ]

    def index
      @inboxes = current_account.channels.order(active: :desc, name: :asc)
    end

    def show
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