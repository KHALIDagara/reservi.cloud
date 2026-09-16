class ApplicationController < ActionController::Base
  include Authentication
  include AccountScoping
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Reservi::Errors::OperationError, with: :operation_error
  rescue_from Reservi::Errors::AuthorizationError, with: :authorization_error

  private

    def operation_error(exception)
      flash[:alert] = exception.message
      redirect_back fallback_location: root_url, status: :see_other
    end

    def authorization_error(exception)
      redirect_to accounts_url, alert: exception.message, status: :see_other
    end
end
