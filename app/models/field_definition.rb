class FieldDefinition < ApplicationRecord
  SCOPES = %w[customer conversation].freeze
  TYPES = %w[text number boolean single_choice multi_choice date].freeze
  BUILT_IN_BINDINGS = %w[name phone email_address locale].freeze

  belongs_to :account

  validates :scope, inclusion: { in: SCOPES }
  validates :key, presence: true, uniqueness: { scope: [:account_id, :scope] }
  validates :field_type, inclusion: { in: TYPES }
  validates :built_in_binding, inclusion: { in: BUILT_IN_BINDINGS }, allow_nil: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :for_customer, -> { where(scope: "customer").ordered }
  scope :for_conversation, -> { where(scope: "conversation").ordered }
end
