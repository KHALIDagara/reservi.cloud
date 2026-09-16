module Accounts
  class Create
    GENERAL_TEAM_NAME = "General"

    def self.call(user:, name:, operation_key:, locale: "en", timezone: "UTC")
      new(user:, name:, operation_key:, locale:, timezone:).call
    end

    def initialize(user:, name:, operation_key:, locale: "en", timezone: "UTC")
      @user = user
      @name = name
      @operation_key = operation_key
      @locale = locale
      @timezone = timezone
    end

    # Atomic, idempotent Account bootstrap (accounts-and-ai-setup §2): Account,
    # creator's administrator Membership + human Agent, default General Team and
    # the TeamMembership are created together. A repeated call with the same
    # operation key returns the existing Account and never creates a second
    # tenant (unique index on accounts.creation_operation_key is the guard).
    #
    # Returns the Account on success, the invalid Account with errors on
    # validation failure, or nil when a duplicate operation key is detected
    # but the original Account no longer exists (impossible in practice).
    def call
      existing = Account.find_by(creation_operation_key: @operation_key)
      return existing if existing

      account = Account.new(
        name: @name,
        locale: @locale,
        timezone: @timezone,
        creation_operation_key: @operation_key,
        settings: { "onboarding" => { "setup_steps_completed" => [ "account" ], "dismissed" => false } }
      )
      return account unless account.valid?

      Account.transaction do
        account.save!
        membership = account.memberships.create!(user: @user, role: "admin", active: true)
        agent = account.agents.create!(kind: "human", membership:, name: @user.name, active: true)
        team = account.teams.create!(name: GENERAL_TEAM_NAME, active: true)
        account.team_memberships.create!(team:, agent:, active: true)
        account
      end
    rescue ActiveRecord::RecordNotUnique
      Account.find_by(creation_operation_key: @operation_key)
    end
  end
end
