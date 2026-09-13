class RuleExecution < ApplicationRecord
  belongs_to :conversation
  belongs_to :stage

  validates :execution_key, presence: true, uniqueness: true
  validates :rule_key, presence: true
  validates :status, inclusion: { in: %w[evaluated executed failed skipped] }

  scope :executed, -> { where(status: "executed") }
  scope :for_rule, ->(rule_key) { where(rule_key: rule_key) }
end