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
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false

    before_action :verify_signature

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

    # Twilio signs each request with the auth token over the URL and sorted
    # params. Without a configured token the endpoint refuses everything rather
    # than defaulting to open — a misconfiguration must fail closed.
    def verify_signature
      return head(:forbidden) if auth_token.blank?
      return if ActiveSupport::SecurityUtils.secure_compare(expected_signature, provided_signature)

      # The commonest cause of this is the signed URL not matching the one Rails
      # reconstructs — a proxy, a trailing slash, http vs https. Log the URL used
      # so that is diagnosable without guessing. No secret is logged.
      Rails.logger.warn(
        "[whatsapp] signature rejected. Verified against #{webhook_url.inspect}. " \
        "If Twilio is configured with a different URL, set TWILIO_WEBHOOK_URL to match."
      )
      head :forbidden
    end

    # Twilio signs the URL exactly as configured in its console. Behind a proxy
    # the reconstructed URL can differ, so allow it to be pinned.
    def webhook_url
      ENV["TWILIO_WEBHOOK_URL"].presence || request.original_url
    end

    def provided_signature
      request.headers["X-Twilio-Signature"].to_s
    end

    def expected_signature
      data = webhook_url + request.request_parameters.sort.flatten.join
      Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", auth_token, data))
    end

    def auth_token
      ENV["TWILIO_AUTH_TOKEN"]
    end
  end
end
