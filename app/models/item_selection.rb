class ItemSelection < ApplicationRecord
  belongs_to :conversation
  belongs_to :account
  belongs_to :catalog
  belongs_to :item

  validates :role_key, presence: true
  validates :item_id, uniqueness: { scope: [:conversation_id, :role_key] }

  scope :for_role, ->(key) { where(role_key: key) }
end