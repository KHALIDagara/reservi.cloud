module Invitations
  class Accept
    # Verifies every authority/validity condition and atomically creates (or
    # reactivates) one Membership, human Agent and TeamMemberships under the
    # Account row lock, then consumes the invitation. Repeated and concurrent
    # acceptance produce exactly one Membership/Agent (INV-131).
    def self.call(invitation:, token:, user:)
      new(invitation:, token:, user:).call
    end

    # Translation of every preflight guard into an operator-facing message, or
    # nil when acceptance may proceed. Used by the confirmation page and by
    # call itself so the UI never shows a form that cannot succeed.
    def self.blocking_reason(invitation:, user:, token:)
      return "This invitation was already used." if invitation.status == "accepted"
      return "This invitation was revoked." if invitation.status == "revoked"
      return "This invitation link is invalid." unless invitation.matches_token?(token)
      return "This invitation has expired." if invitation.expired?
      return "Verify your email address before accepting an invitation." unless user.verified?
      if invitation.email != user.email_address
        return "This invitation was sent to a different email address (#{invitation.email})."
      end
      return "This Account is no longer active." unless invitation.account.active?

      nil
    end

    def initialize(invitation:, token:, user:)
      @invitation = invitation
      @token = token
      @user = user
    end

    def call
      reason = self.class.blocking_reason(invitation: @invitation, user: @user, token: @token)
      raise Reservi::Errors::OperationError, reason if reason

      @invitation.account.with_lock do
        @invitation.reload
        raise Reservi::Errors::OperationError, "This invitation was already used." if @invitation.status == "accepted"

        raise Reservi::Errors::OperationError, "This invitation is no longer valid." unless @invitation.valid_for_acceptance?
        raise Reservi::Errors::OperationError, "You are already an active member of this Account." if active_membership_exists?

        ensure_teams_still_valid!
        membership = build_membership!
        agent = build_agent!(membership)
        replace_team_memberships!(agent)
        @invitation.update!(
          status: "accepted",
          accepted_by_membership: membership,
          accepted_at: Time.current,
          delivery_token: nil
        )
        membership
      end
    end

    private

    def active_membership_exists?
      @invitation.account.memberships.active.exists?(user_id: @user.id)
    end

    def ensure_teams_still_valid!
      valid_teams = @invitation.account.teams.active.where(id: @invitation.team_ids).count
      return if valid_teams == @invitation.team_ids.length

      raise Reservi::Errors::OperationError,
        "One or more invited teams no longer exist. Ask an administrator to send a corrected invitation."
    end

    # Inactive previous memberships are reactivated with the *new* role and
    # teams; old administrator permissions/private teams are not restored.
    def build_membership!
      membership = @invitation.account.memberships.find_by(user_id: @user.id)
      membership ||= @invitation.account.memberships.build(user: @user)
      membership.role = @invitation.role
      membership.active = true
      membership.save!
      membership
    end

    def build_agent!(membership)
      agent = @invitation.account.agents.find_by(membership_id: membership.id)
      agent ||= @invitation.account.agents.build(membership_id: membership.id)
      agent.kind = "human"
      agent.name = @user.name
      agent.active = true
      agent.save!
      agent
    end

    def replace_team_memberships!(agent)
      agent.team_memberships.where.not(team_id: @invitation.team_ids).update_all(active: false)
      @invitation.team_ids.each do |team_id|
        team_membership = agent.team_memberships.find_or_initialize_by(team_id:)
        team_membership.account = @invitation.account
        team_membership.active = true
        team_membership.save!
      end
    end
  end
end