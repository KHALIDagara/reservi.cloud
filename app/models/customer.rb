class Customer < ApplicationRecord
  belongs_to :account

  has_many :conversations

  validates :name, presence: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :phone, with: ->(p) { p.strip }
end