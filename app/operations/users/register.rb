module Users
  # Registration + first verification token. Persisted users are already
  # unverified; the verification mail is durable work with the same token.
  class Register
    def self.call(email_address:, name:, password:, password_confirmation:)
      user = User.new(
        email_address:,
        name:,
        password:,
        password_confirmation:
      )
      user.save
      return user if user.errors.any?

      token = user.set_verification_token!
      Users::DeliverVerificationJob.perform_later(user)
      user
    end
  end
end