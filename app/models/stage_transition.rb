class StageTransition < ApplicationRecord
  belongs_to :conversation
  belongs_to :from_stage, class_name: "Stage"
  belongs_to :to_stage, class_name: "Stage", optional: true

  validates :entry_identity, presence: true, uniqueness: { scope: :conversation_id }
end