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
  include MetaWebhookVerification

  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication
  before_action :authenticate_channel, only: [ :dev_inbound, :dev_status ]
  before_action :set_channel_from_token, only: [ :whatsapp_verify, :whatsapp_events, :instagram_verify, :instagram_events ]

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

  # ---- Meta webhook endpoints ----

  # GET /webhooks/whatsapp/:token — Meta challenge-response verification
  def whatsapp_verify
    verify_meta_webhook(@channel)
  end

  # POST /webhooks/whatsapp/:token — inbound WhatsApp events
  def whatsapp_events
    body = request.body.read
    parsed = JSON.parse(body) rescue {}

    receipt = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: extract_whatsapp_event_id(parsed),
      event_type: extract_whatsapp_event_type(parsed),
      payload: parsed
    )
    head(:ok) and return unless receipt.previously_new_record?

    receipt.update!(processed_at: Time.current)

    normalized = Reservi::Channels::WhatsappCloudAdapter.normalize_payload(parsed)
    process_normalized_message(@channel, normalized) if normalized

    head :ok
  end

  # GET /webhooks/instagram/:token — Meta challenge-response verification
  def instagram_verify
    verify_meta_webhook(@channel)
  end

  # POST /webhooks/instagram/:token — inbound Instagram events
  def instagram_events
    body = request.body.read
    parsed = JSON.parse(body) rescue {}

    receipt = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: extract_instagram_event_id(parsed),
      event_type: extract_instagram_event_type(parsed),
      payload: Array.wrap(parsed)
    )
    head(:ok) and return unless receipt.previously_new_record?

    receipt.update!(processed_at: Time.current)

    normalized = Reservi::Channels::InstagramAdapter.normalize_payload(Array.wrap(parsed))
    process_normalized_message(@channel, normalized) if normalized

    head :ok
  end

  private

  def authenticate_channel
    token = params[:token]
    @channel = Channel.active.find_by(inbound_token: token)
    render json: { error: "Unauthorized" }, status: :unauthorized unless @channel
  end

  def set_channel_from_token
    @channel = Channel.find_by!(inbound_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Not found", status: :not_found
  end

  def extract_whatsapp_event_id(payload)
    entry = payload&.dig("entry", 0)
    changes = entry&.dig("changes", 0)
    value = changes&.dig("value")
    msg = value&.dig("messages", 0) || value&.dig("statuses", 0)
    msg&.dig("id") || "unknown_#{Time.current.to_i}"
  end

  def extract_whatsapp_event_type(payload)
    value = payload&.dig("entry", 0, "changes", 0, "value")
    if value&.dig("statuses")
      "message_status"
    elsif value&.dig("messages")
      "message"
    else
      "unknown"
    end
  end

  def extract_instagram_event_id(payload)
    messaging = payload.is_a?(Array) ? payload.first : payload
    msgs = messaging&.dig("messaging") || []
    entry = msgs.first || {}
    entry.dig("message", "mid") || entry.dig("read", "mid") || "unknown_#{Time.current.to_i}"
  end

  def extract_instagram_event_type(payload)
    messaging = payload.is_a?(Array) ? payload.first : payload
    msgs = messaging&.dig("messaging") || []
    entry = msgs.first || {}
    if entry["message"]
      "message"
    elsif entry["read"]
      "message_status"
    else
      "unknown"
    end
  end

  def process_normalized_message(channel, normalized)
    case normalized[:type]
    when "message"
      # Find or create thread + conversation
      thread = channel.channel_threads.find_or_create_by!(
        account: channel.account,
        external_thread_id: normalized[:from]
      ) do |t|
        t.external_contact_name = normalized[:contact_name] || normalized[:from]
        t.external_contact_id = normalized[:from]

        # Create conversation for new thread
        account = channel.account
        customer = account.customers.create!(name: t.external_contact_name)
        flow_version = ensure_flow_version(account)
        first_stage = flow_version.stages.order(:position).first
        conv = account.conversations.create!(
          customer: customer,
          flow_version: flow_version,
          current_stage: first_stage,
          process_status: "active",
          attention: true,
          first_attention_at: Time.current,
          custom_values: {}
        )
        t.conversation = conv
      end

      conv = thread.conversation

      Messages::Create.call(
        conversation: conv,
        agent: nil,
        author_name: normalized[:contact_name] || normalized[:from],
        content: normalized[:body] || "(media message)",
        direction: "inbound"
      )

      conv.update!(
        last_activity_at: Time.current,
        attention: true,
        first_attention_at: conv.first_attention_at || Time.current
      )

      # Evaluate rules (flow) — fire and forget
      if conv.active? && conv.current_stage
        begin
          Reservi::RuleExecutor.evaluate(conversation: conv)
        rescue => e
          Rails.logger.error "Rule evaluation failed for conversation #{conv.id}: #{e.class}: #{e.message}"
        end
      end

    when "message_status"
      # Update delivery status
      delivery = MessageDelivery.find_by(
        channel: channel,
        provider_message_id: normalized[:provider_message_id]
      )
      mapped = map_meta_status(normalized[:status])
      if delivery && delivery.can_transition_to?(mapped)
        delivery.update!(status: mapped)
        delivery.message.update!(delivery_status: mapped)
      end
    end
  end

  def map_meta_status(meta_status)
    case meta_status
    when "sent"      then "sent"
    when "delivered" then "delivered"
    when "read"      then "delivered"
    when "failed"    then "failed"
    else "unknown"
    end
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
