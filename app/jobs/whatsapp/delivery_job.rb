module Whatsapp
  # Sends one outbox row.
  #
  # A job rather than an inline send, so a provider being slow or down does not
  # hold up the webhook, and so Solid Queue's retries apply — which only became
  # possible once jobs survived a restart.
  class DeliveryJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(outbound_message_id)
      message = OutboundMessage.find_by(id: outbound_message_id)
      return if message.nil? || message.sent? || message.delivered? || message.skipped?

      result = Messaging::Adapter.build.deliver(message)

      if result.success?
        message.mark_sent!(provider_message_id: result.provider_message_id)
      else
        # Recorded on the row before raising, so the outbox shows why even while
        # retries are still in flight.
        message.mark_failed!(result.error)
        raise "delivery failed: #{result.error}"
      end
    end
  end
end
