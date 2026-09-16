class Membership < ApplicationRecord
  ROLES = %w[admin manager operator].freeze

  belongs_to :account
  belongs_to :user
  has_one :agent, -> { where(kind: "human") }

  validates :role, inclusion: { in: ROLES }

  scope :active, -> { where(active: true) }
  scope :admins, -> { active.where(role: "admin") }

  def admin?  = role == "admin"
  def manager? = %w[admin manager].include?(role)
end
