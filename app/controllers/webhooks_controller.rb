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

      # Wake up AI if the current owner is an active AI agent
      owner = conversation.owner
      if owner&.kind == "ai" && owner.active_for_work?
        begin
          AiRuns::Admit.call(agent: owner, conversation: conversation, trigger: "inbound")
        rescue => e
          Rails.logger.error "AI admission failed for conversation #{conversation.id}: #{e.class}: #{e.message}"
        end
      end
    end

    # Broadcast realtime update to open inboxes
    publish_conversation_changed(conversation, :message_created)

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
    process_whatsapp_payload(parsed)
  end

  # GET /webhooks/instagram/:token — Meta challenge-response verification
  def instagram_verify
    verify_meta_webhook(@channel)
  end

  # POST /webhooks/instagram/:token — inbound Instagram events
  def instagram_events
    body = request.body.read
    parsed = JSON.parse(body) rescue {}
    process_instagram_payload(parsed)
  end

  def meta_whatsapp_verify
    channel = Channel.active.find_by(provider_type: "whatsapp")
    return render plain: "Channel not found", status: :not_found unless channel

    expected = ensure_webhook_verify_token(channel)
    supplied = params["hub.verify_token"].to_s

    if params["hub.mode"] == "subscribe" && expected.present? &&
        ActiveSupport::SecurityUtils.secure_compare(supplied, expected) &&
        params["hub.challenge"].present?
      render plain: params["hub.challenge"], status: :ok
    else
      render plain: "Verification failed", status: :forbidden
    end
  end

  def meta_instagram_verify
    channel = Channel.active.find_by(provider_type: "instagram")
    return render plain: "Channel not found", status: :not_found unless channel

    expected = ensure_webhook_verify_token(channel)
    supplied = params["hub.verify_token"].to_s

    if params["hub.mode"] == "subscribe" && expected.present? &&
        ActiveSupport::SecurityUtils.secure_compare(supplied, expected) &&
        params["hub.challenge"].present?
      render plain: params["hub.challenge"], status: :ok
    else
      render plain: "Verification failed", status: :forbidden
    end
  end

  def meta_whatsapp_events
    body = request.body.read
    return head :unauthorized unless valid_meta_signature?(body, "whatsapp")

    parsed = JSON.parse(body)
    phone_number_id = parsed.dig("entry", 0, "changes", 0, "value", "metadata", "phone_number_id")
    @channel = oauth_channel_for("whatsapp", phone_number_id)
    return head :not_found unless @channel

    process_whatsapp_payload(parsed)
  rescue JSON::ParserError
    head :unprocessable_content
  end

  def meta_instagram_events
    body = request.body.read
    return head :unauthorized unless valid_meta_signature?(body, "instagram")

    parsed = JSON.parse(body)
    instagram_id = Array.wrap(parsed).first&.dig("id") || Array.wrap(parsed).first&.dig("entry", 0, "id")
    @channel = oauth_channel_for("instagram", instagram_id)
    return head :not_found unless @channel

    process_instagram_payload(parsed)
  rescue JSON::ParserError
    head :unprocessable_content
  end

  private

  def process_whatsapp_payload(parsed)
    event_id = extract_whatsapp_event_id(parsed)
    receipt = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: event_id,
      event_type: extract_whatsapp_event_type(parsed),
      payload: parsed
    )
    if receipt.previously_new_record? || receipt.processed_at.nil?
      process_domain_work(receipt) do
        normalized = Reservi::Channels::WhatsappCloudAdapter.normalize_payload(parsed)
        process_normalized_message(@channel, normalized) if normalized
      end
    end
    head :ok
  end

  def process_instagram_payload(parsed)
    entries = instagram_entries(parsed)
    event_id = extract_instagram_event_id(entries)
    receipt = WebhookReceipt.process!(
      channel: @channel,
      provider_event_id: event_id,
      event_type: extract_instagram_event_type(entries),
      payload: Array.wrap(parsed)
    )
    if receipt.previously_new_record? || receipt.processed_at.nil?
      process_domain_work(receipt) do
        normalized = Reservi::Channels::InstagramAdapter.normalize_payload(entries)
        process_normalized_message(@channel, normalized) if normalized
      end
    end
    head :ok
  end

  def verify_global_meta_webhook(provider)
    expected = ENV["#{provider.upcase}_WEBHOOK_VERIFY_TOKEN"] || ENV["META_WEBHOOK_VERIFY_TOKEN"]
    supplied = params["hub.verify_token"]
    if params["hub.mode"] == "subscribe" && expected.present? && supplied.present? &&
        ActiveSupport::SecurityUtils.secure_compare(supplied, expected) && params["hub.challenge"].present?
      render plain: params["hub.challenge"], status: :ok
    else
      render plain: "Verification failed", status: :forbidden
    end
  end

  def valid_meta_signature?(body, provider)
    secret = ENV[provider == "whatsapp" ? "WHATSAPP_APP_SECRET" : "INSTAGRAM_APP_SECRET"]
    signature = request.headers["X-Hub-Signature-256"].to_s
    return false if secret.blank? || signature.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
    signature.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def oauth_channel_for(provider, external_id)
    return if external_id.blank?

    Channel.active.find_by(provider_type: provider, provider_external_id: external_id.to_s)
  end

  def process_domain_work(receipt, &block)
    block.call
    receipt.update!(processed_at: Time.current)
  rescue => e
    Rails.logger.error "Webhook domain processing failed for receipt #{receipt.id}: #{e.class}: #{e.message}"
    # Leave processed_at nil so the next delivery can retry
  end

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

  def instagram_entries(payload)
    payload.is_a?(Hash) && payload["entry"].present? ? payload["entry"] : Array.wrap(payload)
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

      # Apply channel default assignment for brand-new conversations (not replay)
      apply_channel_default_assignment(conv)

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

        # Wake up AI if the current owner is an active AI agent
        owner = conv.owner
        if owner&.kind == "ai" && owner.active_for_work?
          begin
            AiRuns::Admit.call(agent: owner, conversation: conv, trigger: "inbound")
          rescue => e
            Rails.logger.error "AI admission failed for conversation #{conv.id}: #{e.class}: #{e.message}"
          end
        end
      end

      # Broadcast realtime update to open inboxes
      publish_conversation_changed(conv, :message_created)

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

      # Apply channel default assignment for new conversations
      apply_channel_default_assignment(conversation)

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

  def ensure_webhook_verify_token(channel)
    token = channel.provider_config["webhook_verify_token"].to_s
    if token.blank?
      token = SecureRandom.urlsafe_base64(32)
      config = channel.provider_config.merge("webhook_verify_token" => token)
      channel.update_column(:provider_config, config)
    end
    token
  end

  def apply_channel_default_assignment(conversation)
    channel = conversation.channel_threads.first&.channel
    return unless channel

    if channel.default_agent_id.present? && conversation.owner_id.nil?
      default_agent = channel.default_agent
      return unless default_agent&.assignable?

      Conversations::Claim.call(conversation: conversation, agent: default_agent)
      if default_agent.kind == "ai" && default_agent.active_for_work?
        AiRuns::Admit.call(agent: default_agent, conversation: conversation, trigger: "inbound")
      end
    elsif channel.default_team_id.present? && conversation.team_id.nil?
      conversation.update!(team_id: channel.default_team_id)
    end
  rescue => e
    Rails.logger.error "Default assignment failed for conversation #{conversation.id}: #{e.class}: #{e.message}"
  end

  private

  def publish_conversation_changed(conversation, event)
    return unless conversation&.persisted?
    Realtime::ConversationChangedJob.perform_later(
      account_id:      conversation.account_id,
      conversation_id: conversation.id,
      revision:        conversation.revision,
      event:
    )
  end
end
