class Item < ApplicationRecord
  belongs_to :catalog
  belongs_to :account

  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(title: :asc) }
end
