class MessageDeliveryJob < ApplicationJob
  queue_as :default
  retry_on StandardError, attempts: 3, wait: :exponentially_longer

  # Sends a message via the channel adapter.
  # Handles the pending→sending→sent/failed/unknown lifecycle.
  #
  # Crash safety:
  #   - If the worker crashes before updating the delivery, the status
  #     remains "pending" and the job will be re-enqueued (at-least-once).
  #   - If the worker crashes after the adapter returns success but before
  #     updating the record, the reconciliation callback or sweep handles it.
  def perform(delivery_id)
    delivery = MessageDelivery.find(delivery_id)
    return unless delivery.pending?

    channel = delivery.channel
    adapter = Reservi::Channels::BaseAdapter.for_provider(channel.provider_type)

    # Mark as sending
    delivery.update!(status: "sending", last_attempt_at: Time.current)

    # Send via adapter
    result = adapter.send_message(message_delivery: delivery)

    delivery.update!(
      status: result[:status],
      provider_message_id: result[:provider_message_id],
      error_message: result[:error]
    )

    # Update the message delivery_status
    delivery.message.update!(delivery_status: result[:status])
  end
end