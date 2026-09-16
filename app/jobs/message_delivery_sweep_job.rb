# Periodic sweep job that recovers deliveries stuck in intermediate states.
#
# Recovery scenarios:
#   1. Pending deliveries older than 5 minutes → re-enqueue (job may have been lost)
#   2. Sending deliveries older than 5 minutes → mark as "unknown" (worker crashed mid-send)
#
# The sweep is idempotent: each sweep cycle picks up deliveries in recoverable states
# within the age threshold and either re-enqueues or marks them as unknown.
class MessageDeliverySweepJob < ApplicationJob
  queue_as :default
  STALE_THRESHOLD = 5.minutes

  def perform
    recover_stale_pending
    recover_stuck_sending
  end

  private

  def recover_stale_pending
    # Atomically claim stale pending deliveries. The UPDATE ... WHERE ...
    # ensures we only transition records that are still pending (avoids
    # racing with the original MessageDeliveryJob — H4).
    ids = MessageDelivery.pending
      .where("created_at < ?", STALE_THRESHOLD.ago)
      .limit(50)
      .pluck(:id)

    return if ids.empty?

    # Atomic claim: only update rows that are still pending
    updated = MessageDelivery.where(id: ids, status: "pending")
      .update_all([ "status = 'sending', last_attempt_at = ?", Time.current ])

    # Re-fetch only the rows we successfully claimed
    MessageDelivery.where(id: ids, status: "sending").find_each do |delivery|
      MessageDeliveryJob.perform_later(delivery.id)
    end
  end

  def recover_stuck_sending
    # Atomically claim stuck sending deliveries. The UPDATE will only
    # affect records that are still in "sending" state.
    ids = MessageDelivery.sending
      .where("updated_at < ?", STALE_THRESHOLD.ago)
      .limit(50)
      .pluck(:id)

    return if ids.empty?

    updated = MessageDelivery.where(id: ids, status: "sending")
      .update_all([ "status = 'unknown', error_message = ?, updated_at = ?",
        "Delivery stuck in sending state — recovered by sweep", Time.current ])

    # Re-fetch only claimed rows and update their messages
    MessageDelivery.where(id: ids, status: "unknown").find_each do |delivery|
      delivery.message.update!(delivery_status: "unknown")
    end
  end
end
