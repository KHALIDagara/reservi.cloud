class UserMailer < ApplicationMailer
  def verification(user, raw_token)
    @user = user
    @verify_url = verify_email_url(token: raw_token)

    mail(to: user.email_address, subject: "Verify your email address")
  end
end