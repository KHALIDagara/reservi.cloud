module Invitations
  # Create one pending AccountInvitation per normalized email, role and team
  # set. Only an active administrator of the Account may invite; inviter
  # authority is rechecked here, not trusted from the request.
  class Create
    MAX_EMAILS_PER_REQUEST = 50

    def self.call(account:, actor_membership:, emails:, role:, team_ids:)
      new(account:, actor_membership:, emails:, role:, team_ids:).call
    end

    def initialize(account:, actor_membership:, emails:, role:, team_ids:)
      @account = account
      @actor_membership = actor_membership
      @role = role
      @team_ids = Array(team_ids).map(&:to_i).uniq
      @emails = Array(emails).flat_map { |e| e.to_s.split(/[\s,]+/) }.map(&:strip).reject(&:blank?).uniq
    end

    def call
      ensure_admin!
      ensure_team_membership!
      ensure_emails_present!
      @emails.map { |email| create_one(email) }.compact
    end

    private

    def ensure_admin!
      policy = Accounts::Policy.new(@actor_membership)
      raise Reservi::Errors::AuthorizationError, "Only an Account administrator can send invitations." unless policy.admin?
    end

    def ensure_team_membership!
      existing = @account.teams.active.where(id: @team_ids)
      missing = @team_ids - existing.pluck(:id)
      raise Reservi::Errors::OperationError, "One or more selected teams no longer exist." if missing.any?
      raise Reservi::Errors::OperationError, "Choose at least one team." if @team_ids.empty?
    end

    def ensure_emails_present!
      if @emails.empty?
        raise Reservi::Errors::OperationError, "Enter at least one email address."
      end
      if @emails.length > MAX_EMAILS_PER_REQUEST
        raise Reservi::Errors::OperationError, "Invite at most #{MAX_EMAILS_PER_REQUEST} people at once."
      end
    end

    def create_one(email)
      if active_member?(email)
        raise Reservi::Errors::OperationError, "#{email} is already an active member of this Account."
      end

      pending = @account.account_invitations.pending.find_by(email:)
      raise Reservi::Errors::OperationError, "#{email} already has a pending invitation." if pending

      invitation = @account.account_invitations.new(
        email:,
        role: @role,
        team_ids: @team_ids,
        inviter_membership: @actor_membership,
        delivery_status: "pending"
      )
      invitation.create_token!
      invitation.save!
      Invitations::DeliverJob.perform_later(invitation)
      invitation
    rescue ActiveRecord::RecordNotUnique
      raise Reservi::Errors::OperationError, "#{email} already has a pending invitation."
    end

    def active_member?(email)
      user = User.find_by(email_address: email)
      user && @account.memberships.active.exists?(user_id: user.id)
    end
  end
end
