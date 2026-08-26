require "test_helper"

# Inbound WhatsApp. The conversation is only worth having if it cannot do things
# a resident cannot do on the web, so most of this tests refusals.
class WhatsappInboundTest < ActionDispatch::IntegrationTest
  AUTH_TOKEN = "test-auth-token".freeze

  setup do
    ENV["TWILIO_AUTH_TOKEN"] = AUTH_TOKEN
    PaperTrail.request.whodunnit = users(:registrar).id.to_s

    @household = Household.create!(name: "Moyo homestead",
                                   principal_contact: "0771234567",
                                   location_description: "Past the borehole",
                                   capture_source: :assisted_visit,
                                   change_reason: "capture")
    @member = @household.people.create!(name: "Tanaka Moyo", relationship: :child,
                                        age_band: :age_5_17, residency_status: :resident,
                                        consent_purposes: %w[communication])
    @known = "+263771234567"
    @stranger = "+263779999999"

    PaperTrail.request.whodunnit = nil
  end

  teardown { ENV.delete("TWILIO_AUTH_TOKEN") }

  # Twilio signs the URL plus sorted params with the auth token.
  def send_message(from:, body:, sid: nil)
    sid ||= "SM#{SecureRandom.hex(8)}"
    params = { "From" => "whatsapp:#{from}", "Body" => body, "MessageSid" => sid }
    url = "http://www.example.com/webhooks/whatsapp"
    data = url + params.sort.flatten.join
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", AUTH_TOKEN, data))

    post "/webhooks/whatsapp", params: params,
         headers: { "X-Twilio-Signature" => signature }
  end

  def last_reply = OutboundMessage.order(:created_at).last&.body

  # --- the endpoint itself -------------------------------------------------

  test "an unsigned request is refused and writes nothing" do
    assert_no_difference [ -> { InboundMessage.count }, -> { RegistrationRequest.count } ] do
      post "/webhooks/whatsapp",
           params: { "From" => "whatsapp:#{@stranger}", "Body" => "hello" }
    end

    assert_response :forbidden
  end

  test "a wrongly signed request is refused" do
    post "/webhooks/whatsapp",
         params: { "From" => "whatsapp:#{@stranger}", "Body" => "hello" },
         headers: { "X-Twilio-Signature" => "not-the-right-signature" }

    assert_response :forbidden
  end

  test "with no auth token configured the endpoint fails closed" do
    ENV.delete("TWILIO_AUTH_TOKEN")

    post "/webhooks/whatsapp", params: { "From" => "whatsapp:#{@stranger}", "Body" => "hi" }

    assert_response :forbidden
  end

  test "a provider retry of the same message is not processed twice" do
    sid = "SM-duplicate"
    send_message(from: @stranger, body: "hello", sid: sid)

    assert_no_difference -> { InboundMessage.count } do
      send_message(from: @stranger, body: "hello", sid: sid)
    end
  end

  # --- a stranger ----------------------------------------------------------

  test "an unknown number is offered registration, and creates no household" do
    assert_no_difference [ -> { Household.count }, -> { Person.count } ] do
      send_message(from: @stranger, body: "hello")
    end

    assert_response :ok
    assert_match(/not on the village register/i, last_reply)
  end

  test "a stranger completing the flow creates a request, not a record" do
    send_message(from: @stranger, body: "hello")
    send_message(from: @stranger, body: "Tendai Marimo")

    assert_difference -> { RegistrationRequest.count }, 1 do
      assert_no_difference [ -> { Household.count }, -> { ConsentRecord.count } ] do
        send_message(from: @stranger, body: "Past the school, blue gate")
      end
    end

    request = RegistrationRequest.order(:created_at).last
    assert_equal "Tendai Marimo", request.name
    assert_equal "+263779999999", request.contact_number
    assert_match(/Nothing about your household has been recorded/i, last_reply)
  end

  # --- a known household ---------------------------------------------------

  test "a known number gets the menu" do
    send_message(from: @known, body: "hi")

    assert_match(/Update my household/, last_reply)
    assert_match(/Government support/, last_reply)
  end

  test "an update goes back to the verification queue rather than going live" do
    @household.update_columns(status: Household.statuses[:verified])

    send_message(from: @known, body: "1")
    send_message(from: @known, body: "0779998888")

    @household.reload
    assert @household.pending?, "a WhatsApp edit must still be verified"
    assert_includes Household.verification_queue, @household
  end

  test "a support request without agreement creates no case" do
    send_message(from: @known, body: "2")
    send_message(from: @known, body: "1")            # programme
    send_message(from: @known, body: "1")            # member

    assert_no_difference -> { ProgrammeCase.count } do
      send_message(from: @known, body: "no")
    end

    assert_match(/No request has been opened/i, last_reply)
  end

  test "a support request with agreement records consent and opens a case" do
    send_message(from: @known, body: "2")
    send_message(from: @known, body: "1")
    send_message(from: @known, body: "1")

    assert_difference -> { ProgrammeCase.count }, 1 do
      send_message(from: @known, body: "YES")
    end

    programme_case = @household.programme_cases.last
    consent = @member.reload.consent_for(:programme)

    assert_not_nil consent, "consent must be recorded, not assumed"
    assert_equal "whatsapp", consent.channel
    assert_equal "whatsapp", programme_case.audit_trail.last.source_channel
  end

  test "asking twice does not open a second case" do
    3.times { |i| send_message(from: @known, body: [ "2", "1", "1" ][i]) }
    send_message(from: @known, body: "YES")

    # The behaviour that prompted this: "did that send? let me try again".
    assert_no_difference -> { ProgrammeCase.count } do
      3.times { |i| send_message(from: @known, body: [ "2", "1", "1" ][i]) }
      send_message(from: @known, body: "YES")
    end

    assert_match(/already have a request/i, last_reply)
  end

  # --- reads ---------------------------------------------------------------

  test "reads are refused without consent to be contacted" do
    @member.update!(consent_purposes: [], change_reason: "withdrew")

    send_message(from: @known, body: "4")

    assert_match(/cannot send your household's details/i, last_reply)
    assert_not OutboundMessage.order(:created_at).last.disclosure?
  end

  test "a read is recorded as a disclosure" do
    send_message(from: @known, body: "5")

    reply = OutboundMessage.order(:created_at).last
    assert reply.disclosure?, "showing household data must be logged as a disclosure"
  end

  # --- session -------------------------------------------------------------

  test "STOP ends the conversation and clears what was in progress" do
    send_message(from: @known, body: "2")
    conversation = Conversation.find_by(contact_number: @known)
    assert conversation.in_flow?

    send_message(from: @known, body: "STOP")

    assert_equal "idle", conversation.reload.state
    assert_empty conversation.context
  end

  test "a stale half-finished flow does not resume hours later" do
    send_message(from: @known, body: "2")
    conversation = Conversation.find_by(contact_number: @known)
    conversation.update_columns(last_message_at: 2.hours.ago)

    send_message(from: @known, body: "1")

    # Rather than being read as a programme choice from a forgotten conversation.
    assert_match(/Update my household/, last_reply)
  end

  test "every message is stored verbatim as evidence" do
    send_message(from: @known, body: "2")

    message = InboundMessage.order(:created_at).last
    assert_equal "2", message.body
    assert_equal "+263771234567", message.from_number
    assert_equal @household, message.household
    assert_not_nil message.handled_as
  end
end
