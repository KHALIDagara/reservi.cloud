class KnowledgeRevision < ApplicationRecord
  STATUSES = %w[draft published].freeze

  belongs_to :knowledge_source

  validates :version_number, uniqueness: { scope: :knowledge_source_id }
  validates :status,         inclusion: { in: STATUSES }

  scope :published, -> { where(status: "published") }
  scope :draft,     -> { where(status: "draft") }

  def published?
    status == "published"
  end
end
