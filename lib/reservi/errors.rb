module Reservi
  module Errors
    # Raised by ordinary domain operations when a rule/precondition fails; the
    # controller shows the message to the operator.
    class OperationError < StandardError; end

    # Raised when the current actor is not permitted; controllers redirect or
    # render a 403 and never leak another Account's data.
    class AuthorizationError < StandardError; end
  end
end