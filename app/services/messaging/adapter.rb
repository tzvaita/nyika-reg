module Messaging
  # What every provider must do. Kept to one method because that is genuinely
  # all the registry needs of a provider, and a small interface is what makes
  # swapping Twilio for Meta's Cloud API a configuration change rather than a
  # rewrite.
  class Adapter
    Result = Struct.new(:success?, :provider_message_id, :error, keyword_init: true)

    def deliver(_outbound_message)
      raise NotImplementedError, "#{self.class} must implement #deliver"
    end

    def self.build
      case ENV.fetch("MESSAGING_ADAPTER", "log")
      when "twilio" then Messaging::TwilioAdapter.new
      else Messaging::LogAdapter.new
      end
    end
  end
end
