class KnowledgeSource < ApplicationRecord
  KINDS = %w[qa document scenario].freeze

  belongs_to :account
  belongs_to :current_revision, class_name: "KnowledgeRevision", optional: true

  has_many :revisions, class_name: "KnowledgeRevision", dependent: :destroy
  has_many :grants, class_name: "AgentKnowledgeGrant", dependent: :destroy
  has_many :agents, through: :grants

  validates :title, presence: true, uniqueness: { scope: :account_id }
  validates :kind,  inclusion: { in: KINDS }

  scope :active,  -> { where(archived: false) }
  scope :shared,  -> { where(shared: true) }

  def archived?
    archived
  end
end
