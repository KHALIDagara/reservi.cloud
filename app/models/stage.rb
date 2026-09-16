class Stage < ApplicationRecord
  belongs_to :flow_version

  validates :key, presence: true, uniqueness: { scope: :flow_version_id }
  validates :label, presence: true
  validates :position, presence: true, uniqueness: { scope: :flow_version_id }
end
