class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("RESERVI_MAIL_FROM", "Reservi <no-reply@reservi.local>")
  layout "mailer"
end