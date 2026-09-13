class AddVerificationDeliveryTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    # Short-lived encrypted payload so a retried verification email can reuse
    # the same token after enqueue loss; cleared once verified.
    add_column :users, :verification_delivery_token, :string
  end
end