class Flow < ApplicationRecord
  belongs_to :account
  belongs_to :current_version, class_name: "FlowVersion", optional: true

  has_many :versions, class_name: "FlowVersion"

  validates :name, presence: true
end
