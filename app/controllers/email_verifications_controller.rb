class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    user = User.find_by(verification_token_digest: User.digest(params[:token]))

    if user.nil?
      redirect_to new_session_path, alert: "This verification link is invalid."
      return
    end

    Users::Verify.call(user:, token: params[:token])
    if Current.user
      redirect_to accounts_path, notice: "Your email address is verified."
    else
      redirect_to new_session_path, notice: "Your email address is verified. Please sign in."
    end
  rescue Reservi::Errors::OperationError => e
    redirect_to new_session_path, alert: e.message
  end

  def resend
    return redirect_to new_session_path unless Current.user
    if Current.user.verified?
      redirect_to accounts_path, notice: "Your email address is already verified."
      return
    end
    if Current.user.verification_delivery_token.blank?
      redirect_to accounts_path, alert: "No verification link is pending for this account."
      return
    end

    Users::DeliverVerificationJob.perform_later(Current.user)
    redirect_to accounts_path, notice: "A verification email is on its way."
  end
end
