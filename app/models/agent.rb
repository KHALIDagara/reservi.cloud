class Agent < ApplicationRecord
  KINDS              = %w[human ai].freeze
  OPERATIONAL_STATUSES = %w[draft active paused archived].freeze

  belongs_to :account
  # Present only for human Agents (enforced by agents_kind_membership_check).
  belongs_to :membership, optional: true
  belongs_to :agent_configuration, optional: true

  has_many :team_memberships
  has_many :teams, through: :team_memberships
  has_many :owned_conversations, class_name: "Conversation", foreign_key: :owner_id, inverse_of: :owner
  has_many :appointments, foreign_key: :scheduled_agent_id, inverse_of: :scheduled_agent
  has_one :calendar_setting, dependent: :destroy
  has_many :appointment_events, foreign_key: :actor_id, inverse_of: :actor
  has_many :ai_runs
  has_many :agent_configurations
  has_many :knowledge_grants, class_name: "AgentKnowledgeGrant"
  has_many :knowledge_sources, through: :knowledge_grants

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :operational_status, inclusion: { in: OPERATIONAL_STATUSES }
  validates :membership_id, uniqueness: { scope: :account_id }, if: -> { membership_id.present? }

  scope :active,        -> { where(active: true) }
  scope :human,         -> { where(kind: "human") }
  scope :ai,            -> { where(kind: "ai") }
  scope :operational,   -> { where(operational_status: %w[active paused]) }
  scope :schedulable,   -> {
    active.human.joins(:membership).where(memberships: { active: true })
  }

  def operational?
    %w[active paused].include?(operational_status)
  end

  def schedulable?
    active? && kind == "human" && membership&.active?
  end
end
