require "net/http"
require "uri"

module Messaging
  # Twilio's WhatsApp API.
  #
  # Chosen for the first real adapter because the SANDBOX needs no Meta business
  # verification: a handset can join it in minutes and the whole flow is
  # demonstrable before any contract exists. Production still needs a WhatsApp
  # sender approved through Twilio.
  #
  # Net::HTTP rather than the twilio-ruby gem: one POST does not justify a
  # dependency, and it keeps the adapter readable as an example for the next one.
  class TwilioAdapter < Adapter
    def deliver(outbound_message)
      params = {
        To: "whatsapp:#{outbound_message.to_number}",
        From: "whatsapp:#{from_number}",
        Body: outbound_message.body
      }
      # Ask Twilio to report what became of it. Without this the outbox only ever
      # knows the message was accepted, never that it arrived.
      params[:StatusCallback] = status_callback_url if status_callback_url.present?

      response = post(params)

      if response.is_a?(Net::HTTPSuccess)
        Adapter::Result.new(success?: true,
                            provider_message_id: JSON.parse(response.body)["sid"])
      else
        Adapter::Result.new(success?: false,
                            error: "#{response.code}: #{response.body.to_s.truncate(200)}")
      end
    rescue StandardError => e
      # A provider being unreachable is an expected condition, not a crash. The
      # outbox records the failure and Solid Queue retries it.
      Adapter::Result.new(success?: false, error: "#{e.class}: #{e.message}")
    end

    private

    def account_sid = ENV["TWILIO_ACCOUNT_SID"]
    def auth_token  = ENV["TWILIO_AUTH_TOKEN"]
    def from_number = ENV.fetch("TWILIO_WHATSAPP_FROM", "+14155238886") # sandbox default

    # Where Twilio should report delivery. Omitted when unset, in which case
    # messages stay at "sent" and the outbox says so honestly.
    def status_callback_url
      ENV["TWILIO_STATUS_CALLBACK_URL"].presence ||
        (ENV["APP_BASE_URL"].presence && "#{ENV['APP_BASE_URL'].chomp('/')}/webhooks/whatsapp/status")
    end

    def post(params)
      uri = URI("https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json")
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(account_sid, auth_token)
      request.set_form_data(params)

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end
    end
  end
end
