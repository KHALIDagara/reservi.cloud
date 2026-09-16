module Users
  class Verify
    def self.call(user:, token:)
      return user if user.verified?

      unless user.matches_verification_token?(token)
        raise Reservi::Errors::OperationError, "This verification link is invalid."
      end

      user.mark_verified!
      user
    end
  end
end
