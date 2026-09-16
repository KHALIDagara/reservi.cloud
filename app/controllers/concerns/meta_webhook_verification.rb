module MetaWebhookVerification
  extend ActiveSupport::Concern

  def verify_meta_webhook(channel)
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    if mode == "subscribe"
      expected_token = channel.provider_config["webhook_verify_token"]
      if token == expected_token && challenge.present?
        render plain: challenge, status: :ok
        return
      end
      render plain: "Verification failed", status: :forbidden
    else
      render plain: "OK", status: :ok
    end
  end
end
