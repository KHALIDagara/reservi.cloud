class Users::DeliverVerificationJob < ApplicationJob
  queue_as :mailers

  def perform(user)
    user = User.find_by(id: user) if user.is_a?(Integer)
    return unless user
    return if user.verified?
    return if user.verification_delivery_token.blank?

    UserMailer.verification(user, user.verification_delivery_token).deliver_now
  end
end
