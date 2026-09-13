class Catalog < ApplicationRecord
  belongs_to :account
  has_many :items, dependent: :destroy

  validates :title, presence: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(title: :asc) }
end