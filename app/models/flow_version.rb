class FlowVersion < ApplicationRecord
  belongs_to :flow

  has_many :stages, dependent: :destroy
  has_many :conversations, foreign_key: :flow_version_id

  validates :version_number, presence: true, uniqueness: { scope: :flow_id }
  validates :status, inclusion: { in: %w[draft published] }

  scope :draft, -> { where(status: "draft") }
  scope :published, -> { where(status: "published") }

  def published?
    status == "published"
  end

  def draft?
    status == "draft"
  end
end