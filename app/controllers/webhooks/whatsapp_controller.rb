module Webhooks
  # Where inbound WhatsApp messages arrive.
  #
  # This endpoint is world-reachable and unauthenticated by nature, so the
  # signature is verified BEFORE the payload is read or anything is written. An
  # unsigned request must not be able to open a case or a registration request.
  #
  # It always answers quickly and never leaks: a provider gets 200 or 403 and
  # nothing about whether a number is known to the registry.
  class WhatsappController < ApplicationController
    include TwilioSignatureVerification

    # A flood cannot be stopped here, but it can be slowed. Rails.cache is now
    # database-backed, so this limit actually holds across processes.
    rate_limit to: 120, within: 1.minute, with: -> { head :too_many_requests }

    def create
      message = record_message
      return head :ok if message.nil? # already seen, or nothing to act on

      reply = Whatsapp::Router.new(message).call
      Whatsapp::DeliveryJob.perform_later(reply.id) if reply

      head :ok
    rescue StandardError => e
      # Never fail a webhook back to the provider: it will retry, and a retry
      # storm on a broken message helps nobody. The message is stored, so it can
      # be replayed once fixed.
      Rails.logger.error("[whatsapp] #{e.class}: #{e.message}")
      head :ok
    end

    private

    # Everything written while handling an inbound message is attributed to
    # WhatsApp, so the pilot can tell chat traffic from staff work.
    def audit_source_channel
      "whatsapp"
    end

    def record_message
      from = params[:From].to_s.sub("whatsapp:", "")
      body = params[:Body].to_s
      provider_id = params[:MessageSid].presence || params[:SmsMessageSid].presence

      return nil if from.blank?
      return nil if InboundMessage.already_seen?(provider_id)

      conversation = Conversation.for_number(from)

      InboundMessage.create!(
        channel: "whatsapp",
        provider_message_id: provider_id,
        from_number: PhoneNumber.normalise(from) || from,
        body: body,
        received_at: Time.current,
        conversation: conversation,
        payload: request.request_parameters.except("Body")
      )
    end

    # Twilio signs the URL as configured in its console; behind a proxy the
    # reconstructed one can differ, so allow it to be pinned.
    def twilio_webhook_url
      ENV["TWILIO_WEBHOOK_URL"].presence || request.original_url
    end
  end
end
