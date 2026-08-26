module Webhooks
  # Delivery status callbacks.
  #
  # Without these, "sent" only means Twilio accepted the message — not that it
  # reached anyone. For a pilot that has to report whether reminders actually
  # work, the difference between accepted, delivered and read is the whole point.
  class WhatsappStatusController < ApplicationController
    include TwilioSignatureVerification

    # Status callbacks are chatty: several per message. The limit is generous.
    rate_limit to: 600, within: 1.minute, with: -> { head :too_many_requests }

    def create
      message = OutboundMessage.find_by(provider_message_id: params[:MessageSid])

      # An unknown SID is not an error worth retrying — it may be a message sent
      # before this table existed, or from another application sharing the
      # account. Acknowledge and move on.
      return head :ok if message.nil?

      message.apply_provider_status!(
        params[:MessageStatus],
        error_code: params[:ErrorCode],
        error_message: params[:ErrorMessage]
      )

      head :ok
    rescue StandardError => e
      # Never fail a callback back to Twilio: it retries, and a retry storm on a
      # broken status update helps nobody.
      Rails.logger.error("[whatsapp:status] #{e.class}: #{e.message}")
      head :ok
    end

    private

    def twilio_webhook_url
      ENV["TWILIO_STATUS_CALLBACK_URL"].presence || request.original_url
    end
  end
end
