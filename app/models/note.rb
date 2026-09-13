class Note < ApplicationRecord
  belongs_to :conversation
  belongs_to :agent

  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
end