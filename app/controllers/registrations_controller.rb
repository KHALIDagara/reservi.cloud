class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 10.minutes, only: :create,
    with: -> { redirect_to register_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    Rails.logger.debug "REGISTRATION: params = #{registration_params.inspect}"
    @user = Users::Register.call(**registration_params)
    Rails.logger.debug "REGISTRATION: user = #{@user.inspect}, persisted = #{@user&.persisted?}"
    Rails.logger.debug "REGISTRATION: user class = #{@user&.class}, persisted? = #{@user&.persisted?}"

    if @user&.persisted?
      start_new_session_for(@user)
      redirect_to accounts_path, notice: "Welcome! Check your email to verify your address."
    else
      Rails.logger.debug "REGISTRATION: rendering new, user = #{@user.inspect}"
      render :new, status: :unprocessable_content
    end
  end

  private

  def registration_params
    params.require(:user)
          .permit(:name, :email_address, :password, :password_confirmation)
          .to_h.symbolize_keys
  end
end
