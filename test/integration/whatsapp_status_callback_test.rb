require "test_helper"

# Delivery status callbacks.
#
# The distinction being tested: "sent" means a provider accepted the message,
# which is not the same as it reaching anyone. A pilot reporting whether
# reminders work needs to tell those apart.
class WhatsappStatusCallbackTest < ActionDispatch::IntegrationTest
  AUTH_TOKEN = "test-auth-token".freeze

  setup do
    ENV["TWILIO_AUTH_TOKEN"] = AUTH_TOKEN
    @message = OutboundMessage.create!(to_number: "+263771234567", body: "Test",
                                       template_key: "menu", status: :sent,
                                       provider_message_id: "SM123", sent_at: 1.minute.ago)
  end

  teardown { ENV.delete("TWILIO_AUTH_TOKEN") }

  def callback(status, sid: "SM123", error_code: nil, error_message: nil)
    params = { "MessageSid" => sid, "MessageStatus" => status }
    params["ErrorCode"] = error_code if error_code
    params["ErrorMessage"] = error_message if error_message

    url = "http://www.example.com/webhooks/whatsapp/status"
    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha1", AUTH_TOKEN, url + params.sort.flatten.join)
    )

    post "/webhooks/whatsapp/status", params: params,
         headers: { "X-Twilio-Signature" => signature }
  end

  test "an unsigned callback is refused and changes nothing" do
    post "/webhooks/whatsapp/status",
         params: { "MessageSid" => "SM123", "MessageStatus" => "delivered" }

    assert_response :forbidden
    assert @message.reload.sent?, "an unsigned callback must not change anything"
  end

  test "delivered is recorded, which sent alone never proved" do
    assert_nil @message.delivered_at

    callback("delivered")

    @message.reload
    assert_response :ok
    assert @message.delivered?
    assert_not_nil @message.delivered_at
    assert @message.reached_recipient?
  end

  test "read is recorded separately from delivered" do
    callback("read")

    @message.reload
    assert @message.delivered?, "a read message has certainly been delivered"
    assert @message.read?, "WhatsApp reports reads, and whether a reminder was seen matters"
    assert_not_nil @message.read_at
  end

  test "a failure records the provider's reason" do
    callback("failed", error_code: "63003", error_message: "Channel could not find To address")

    @message.reload
    assert @message.failed?
    assert_equal "63003", @message.provider_error_code
    assert_match(/63003/, @message.error_message)
  end

  test "undelivered counts as failed" do
    callback("undelivered", error_code: "63016")

    assert @message.reload.failed?
  end

  test "a late callback does not undo a later one" do
    # Twilio does not guarantee order, so a delayed "sent" must not overwrite a
    # "delivered" that already arrived.
    callback("delivered")
    callback("sent")

    @message.reload
    assert @message.delivered?, "an out-of-order callback must not regress the status"
    assert_not_nil @message.delivered_at
  end

  test "a failure always wins, whenever it arrives" do
    callback("delivered")
    callback("failed", error_code: "63003")

    assert @message.reload.failed?,
           "a message that failed did not arrive, however late we hear about it"
  end

  test "an unknown message id is acknowledged rather than retried" do
    callback("delivered", sid: "SM-never-seen")

    assert_response :ok
  end

  test "an unrecognised status is ignored rather than crashing" do
    callback("something-new-from-twilio")

    assert @message.reload.sent?
    assert_response :ok
  end

  test "the adapter asks Twilio for callbacks when a base URL is configured" do
    ENV["TWILIO_STATUS_CALLBACK_URL"] = "https://example.test/webhooks/whatsapp/status"

    adapter = Messaging::TwilioAdapter.new
    assert_equal "https://example.test/webhooks/whatsapp/status",
                 adapter.send(:status_callback_url)
  ensure
    ENV.delete("TWILIO_STATUS_CALLBACK_URL")
  end

  test "no callback is requested when nothing is configured" do
    # Better than pointing Twilio at a guessed URL: messages stay at "sent" and
    # the outbox says so honestly.
    assert_nil Messaging::TwilioAdapter.new.send(:status_callback_url)
  end
end
