class AgentConfiguration < ApplicationRecord
  STATUSES = %w[draft published].freeze

  belongs_to :account
  belongs_to :agent

  has_many :ai_runs, dependent: :restrict_with_error

  validates :version_number, presence: true,
    uniqueness: { scope: :agent_id, message: "must be unique per agent" }
  validates :status, inclusion: { in: STATUSES }

  scope :published, -> { where(status: "published") }
  scope :draft,     -> { where(status: "draft") }

  def published?
    status == "published"
  end
end
