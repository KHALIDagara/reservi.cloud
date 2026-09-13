class Agent < ApplicationRecord
  KINDS = %w[human ai].freeze

  belongs_to :account
  # Present only for human Agents (enforced by agents_kind_membership_check).
  belongs_to :membership, optional: true

  has_many :team_memberships
  has_many :teams, through: :team_memberships

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :membership_id, uniqueness: { scope: :account_id }, if: -> { membership_id.present? }

  scope :active, -> { where(active: true) }
  scope :human, -> { where(kind: "human") }
  scope :ai, -> { where(kind: "ai") }
end