class Attachment < ApplicationRecord
  KINDS = %w[image audio video file].freeze

  belongs_to :message

  has_one_attached :file

  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :images, -> { where(kind: "image") }
  scope :audio,  -> { where(kind: "audio") }
  scope :videos, -> { where(kind: "video") }
  scope :files,  -> { where(kind: "file") }

  def image?
    kind == "image"
  end

  def audio?
    kind == "audio"
  end

  def video?
    kind == "video"
  end
end