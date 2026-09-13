class AccountInvitation < ApplicationRecord
  ROLES = %w[admin manager operator].freeze
  STATUSES = %w[pending accepted revoked].freeze
  DELIVERY_STATUSES = %w[pending delivered failed unknown].freeze
  DEFAULT_TTL = 7.days

  belongs_to :account
  belongs_to :inviter_membership, class_name: "Membership"

  # Accepted-by attribution is optional until acceptance happens.
  belongs_to :accepted_by_membership, class_name: "Membership", optional: true

  # The raw single-use token is kept only as a short-lived encrypted delivery
  # payload and erased once the email is sent (domain-model §33).
  encrypts :delivery_token

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, format: { with: User::VALID_EMAIL }
  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }
  validates :expires_at, presence: true
  validates :team_ids, presence: true

  scope :pending, -> { where(status: "pending") }

  def pending?
    status == "pending"
  end

  def expired?
    expires_at <= Time.current
  end

  def valid_for_acceptance?
    status == "pending" && !expired?
  end

  def matches_token?(raw)
    return false if raw.blank?

    User.secure_compare(token_digest, User.digest(raw))
  end

  def create_token!
    raw = SecureRandom.urlsafe_base64(32)
    self.token_digest = User.digest(raw)
    self.delivery_token = raw
    self.expires_at = Time.current + DEFAULT_TTL
    raw
  end

  def rotate_token!
    create_token!
  end
end