class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 20.minutes

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  VALID_EMAIL = URI::MailTo::EMAIL_REGEXP

  validates :name, presence: true
  validates :email_address, presence: true, format: { with: VALID_EMAIL }, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  def verified?
    verified_at.present?
  end

  # Single-use verification token handling (digest stored, raw token only
  # retained inside the encrypted delivery column until the mail is sent).
  def set_verification_token!
    raw = SecureRandom.urlsafe_base64(32)
    update!(
      verification_token_digest: self.class.digest(raw),
      verification_delivery_token: raw,
      verified_at: nil
    )
    raw
  end

  def matches_verification_token?(raw)
    return false if verified? || raw.blank? || verification_token_digest.blank?

    self.class.secure_compare(verification_token_digest, self.class.digest(raw))
  end

  def mark_verified!
    update!(
      verified_at: Time.current,
      verification_token_digest: nil,
      verification_delivery_token: nil
    )
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.secure_compare(a, b)
    ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
  end
end
