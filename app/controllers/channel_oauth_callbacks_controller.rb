class ChannelOauthCallbacksController < ApplicationController
  def show
    provider = params[:provider].to_s
    raise ActionController::RoutingError, "Not Found" unless provider == "instagram"

    state = oauth_verifier.verify(params.require(:state)).with_indifferent_access
    validate_state!(state, provider:)
    account = Account.find_by!(id: state.fetch(:account_id), active: true)
    membership = account.memberships.active.find_by!(user_id: Current.user.id)
    unless Accounts::Policy.new(membership).admin?
      raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage inboxes."
    end

    connection = Reservi::Channels::OauthClient.new(provider).connect_instagram(
      code: params.require(:code),
      redirect_uri: channel_oauth_callback_url(provider:)
    )
    channel = Channels::Connect.call(account:, connection:)
    redirect_to account_channel_path(account, channel), notice: "Instagram inbox connected."
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActionController::ParameterMissing, KeyError
    redirect_to accounts_path, alert: "This inbox connection expired or is invalid. Please try again."
  rescue ActiveRecord::RecordNotFound, Reservi::Errors::AuthorizationError => e
    redirect_to accounts_path, alert: e.message
  rescue Reservi::Errors::OperationError => e
    redirect_to accounts_path, alert: e.message
  end

  private

  def validate_state!(state, provider:)
    nonce = state.fetch(:nonce)
    nonces = session.fetch(:channel_oauth_nonces, {})
    expected = nonces.delete(nonce)
    session[:channel_oauth_nonces] = nonces
    valid = expected && state.fetch(:user_id).to_i == Current.user.id && state.fetch(:provider) == provider
    raise ActiveSupport::MessageVerifier::InvalidSignature unless valid
  end

  def oauth_verifier
    Rails.application.message_verifier("channel_oauth")
  end
end
