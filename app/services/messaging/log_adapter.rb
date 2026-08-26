module Messaging
  # The default. Records what WOULD have been sent and reports success.
  #
  # This is what makes the whole conversation buildable and testable before any
  # provider contract exists: the router, the consent gates, the templates and
  # the outbox are all real, and only the final hop is simulated.
  class LogAdapter < Adapter
    def deliver(outbound_message)
      Rails.logger.info(
        "[messaging:log] would send to #{outbound_message.to_number}: " \
        "#{outbound_message.body.truncate(120)}"
      )

      Adapter::Result.new(success?: true,
                          provider_message_id: "log-#{SecureRandom.hex(8)}")
    end
  end
end
