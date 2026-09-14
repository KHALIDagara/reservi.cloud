# Inbound webhooks from channel providers.
#
# Protocol:
#   1. Authenticate via channel inbound_token (in URL path).
#   2. Persist receipt immediately (durable acknowledge-first — G24).
#   3. Acknowledge to provider.
#   4. Process asynchronously (no blocking work in this controller).
#
# For the DevAdapter, inbound messages arrive as POST /webhooks/dev/:token
# with JSON body: { thread_id:, content:, author_name: }.
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication
  before_action :authenticate_channel

  # Webhook endpoints respond with JSON, not HTML redirects
  rescue_from Reservi::Errors::OperationError, with: :json_error
  rescue_from ActiveRecord::RecordInvalid, with: :json_validation_error

  # POST /webhooks/dev/:token — inbound customer message
  def dev_inbound
    payload = JSON.parse(request.body.read)

    # Resolve or create thread
    thread = find_or_create_thread(payload["thread_id"], payload["author_name"])

    conversation = thread.conversation

    # Persist the message durably before acknowledging
    message = conversation.messages.create!(
      author_name: payload["author_name"] || "Customer",
      content: payload["content"],
      direction: "inbound",
      delivery_status: "received"
    )

    # Touch the conversation
    conversation.update!(
      last_activity_at: Time.current,
      attention: true,
      first_attention_at: conversation.first_attention_at || Time.current
    )

    # Evaluate rules on active conversations (inbound may trigger routing/assignment).
    # Completed/cancelled conversations raise attention but do not re-run process rules.
    # Always acknowledge even if rule evaluation fails — the message is durably stored.
    if conversation.active?
      begin
        Reservi::RuleExecutor.evaluate(conversation: conversation)
      rescue => e
        Rails.logger.error "Rule evaluation failed for conversation #{conversation.id}: #{e.class}: #{e.message}"
      end
    end

    render json: { status: "accepted", message_id: message.id }
  rescue JSON::ParserError
    render json: { error: "Invalid JSON" }, status: :unprocessable_content
  end

  # POST /webhooks/dev/:token/status — delivery status callback
  def dev_status
    payload = JSON.parse(request.body.read)

    delivery = @channel.deliveries.find_by(provider_message_id: payload["provider_message_id"])
    if delivery
      new_status = payload["status"]
      current_status = delivery.status
      # Directed transition whitelist — prevents regression (G23, M1).
      # A status can only advance to a strictly later state.
      allowed = {
        "pending"  => %w[sending sent failed unknown],
        "sending"  => %w[sent failed delivered unknown],
        "sent"     => %w[delivered],
        "failed"   => %w[],
        "delivered" => %w[],
        "unknown"  => %w[]
      }
      if allowed.fetch(current_status, []).include?(new_status)
        delivery.update!(status: new_status)
        delivery.message.update!(delivery_status: new_status)
      end
    end

    render json: { status: "ok" }
  rescue JSON::ParserError
    render json: { error: "Invalid JSON" }, status: :unprocessable_content
  end

  private

  def authenticate_channel
    token = params[:token]
    @channel = Channel.active.find_by(inbound_token: token)
    render json: { error: "Unauthorized" }, status: :unauthorized unless @channel
  end

  def json_error(exception)
    render json: { error: exception.message }, status: :unprocessable_content
  end

  def json_validation_error(exception)
    render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_content
  end

  def ensure_flow_version(account)
    existing = account.flows.where.not(current_version_id: nil).first
    raise Reservi::Errors::OperationError,
      "No published Flow configured for this Account. " \
      "An administrator must create and publish a Flow before accepting messages." unless existing

    existing.current_version
  end

  def find_or_create_thread(thread_id, author_name)
    # Optimistic find — most requests hit existing threads.
    existing = @channel.channel_threads.find_by(external_thread_id: thread_id)
    return existing if existing

    account = @channel.account
    customer_name = author_name.presence || "Unknown Customer"

    # Create customer and conversation outside the thread record.
    # If the thread insert hits a unique violation (concurrent winner),
    # we clean up the orphan resources.
    customer = nil
    conversation = nil

    begin
      customer = account.customers.create!(name: customer_name)
      flow_version = ensure_flow_version(account)
      first_stage = flow_version.stages.order(:position).first

      conversation = account.conversations.create!(
        customer: customer,
        flow_version: flow_version,
        current_stage: first_stage,
        process_status: "active",
        attention: true,
        first_attention_at: Time.current,
        custom_values: {}
      )

      @channel.channel_threads.create!(
        account: account,
        conversation: conversation,
        external_thread_id: thread_id,
        external_contact_name: customer_name
      )
    rescue ActiveRecord::RecordNotUnique
      # Another request created the thread first — clean up orphans and
      # return the existing thread.
      conversation&.destroy!
      customer&.destroy!
      @channel.channel_threads.find_by!(external_thread_id: thread_id)
    end
  end
end