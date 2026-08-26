# Verifies that a request genuinely came from Twilio.
#
# Both the inbound message webhook and the status callback are world-reachable
# and unauthenticated by nature, so this is the only thing standing between them
# and anyone who knows the URL. It runs before any payload is read.
#
# It FAILS CLOSED: with no auth token configured, every request is refused rather
# than the endpoint defaulting to open. A misconfiguration should stop messages
# arriving, not silently accept forged ones.
module TwilioSignatureVerification
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false
    before_action :verify_twilio_signature
  end

  private

  def verify_twilio_signature
    return head(:forbidden) if twilio_auth_token.blank?
    return if ActiveSupport::SecurityUtils.secure_compare(expected_signature, provided_signature)

    # A proxy, a trailing slash or http-vs-https changing the reconstructed URL
    # is the usual cause, so log which URL was used. No secret is logged.
    Rails.logger.warn(
      "[twilio] signature rejected on #{request.path}. Verified against " \
      "#{twilio_webhook_url.inspect}. If Twilio is configured with a different " \
      "URL, set TWILIO_WEBHOOK_URL or TWILIO_STATUS_CALLBACK_URL to match."
    )
    head :forbidden
  end

  def provided_signature
    request.headers["X-Twilio-Signature"].to_s
  end

  # Twilio signs the URL exactly as configured in its console, plus every POST
  # parameter sorted by name and concatenated.
  def expected_signature
    data = twilio_webhook_url + request.request_parameters.sort.flatten.join
    Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", twilio_auth_token, data))
  end

  # Overridden per endpoint so each can be pinned independently.
  def twilio_webhook_url
    request.original_url
  end

  def twilio_auth_token
    ENV["TWILIO_AUTH_TOKEN"]
  end
end
