# frozen_string_literal: true

module Conversations
  # Creates an outbound message with optional attachments and enqueues
  # delivery via the conversation's channel.  This is the single entry
  # point for sending from the inbox composer — it replaces the bare
  # Messages::Create call that lacked provider delivery.
  #
  # Resolves the correct ChannelThread for this conversation and creates
  # both the local message and the durable delivery intent.
  #
  class SendMessage
    def self.call(conversation:, agent:, content: nil, attachments: [], operation_key: nil)
      new(conversation:, agent:, content:, attachments:, operation_key:).call
    end

    def initialize(conversation:, agent:, content:, attachments:, operation_key:)
      @conversation = conversation
      @agent        = agent
      @content      = content
      @attachments  = attachments
      @operation_key = operation_key || SecureRandom.uuid
    end

    def call
      validate_composable!

      message = nil

      ActiveRecord::Base.transaction do
        # Create the message skeleton first. For attachment-only messages,
        # the content validation is relaxed (content presence is skipped when
        # attachments exist — see Message#has_attachments?). We create the
        # Message record first so it has an ID for attachments to reference,
        # then attach files, then validate+save.
        message = @conversation.messages.new(
          agent: @agent,
          author_name: @agent.name,
          content: @content.presence || "",
          direction: "outbound",
          delivery_status: "local"
        )

        # Attach files before save so has_attachments? returns true
        # during content validation
        attach_files!(message) if @attachments.any?

        # Now save — content validation will see attachments if present
        message.save!

        # Find the appropriate channel for this conversation
        channel_thread = @conversation.channel_threads.first
        if channel_thread&.channel&.active?
          channel = channel_thread.channel

          MessageDeliveries::Send.call(
            conversation: @conversation,
            channel:,
            agent: @agent,
            message: message,
            operation_key: @operation_key
          )
        end

        # Update conversation activity timestamp
        @conversation.touch(:last_activity_at)
      end

      # Broadcast after the transaction commits
      ActiveRecord.after_all_transactions_commit do
        Realtime::ConversationChangedJob.perform_later(
          account_id:      @conversation.account_id,
          conversation_id: @conversation.id,
          revision:        @conversation.revision,
          event:           :message_created,
          actor_id:        @agent&.id
        )
      end

      message
    end

    private

    def validate_composable!
      return if @content.present? || @attachments.any?
      raise Reservi::Errors::OperationError, "Message must have content or at least one attachment."
    end

    def attach_files!(message)
      @attachments.each do |file|
        kind = file_kind(file)
        attachment = message.attachments.create!(kind:)
        attachment.file.attach(file)
      end
    end

    def file_kind(file)
      content_type = file.respond_to?(:content_type) ? file.content_type : ""
      case content_type
      when /^image\// then "image"
      when /^audio\// then "audio"
      when /^video\// then "video"
      else "file"
      end
    end
  end
end