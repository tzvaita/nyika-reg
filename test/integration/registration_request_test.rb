require "test_helper"

# "Ask to be registered" — the only place the public can write.
#
# The property that matters: it creates an inert REQUEST and never touches the
# register. A stranger must not be able to put a household, a person or a consent
# record into the system.
class RegistrationRequestTest < ActionDispatch::IntegrationTest
  def valid_params
    { registration_request: { name: "Tendai Marimo", contact_method: "0771234567",
                              location_hint: "Past the school" } }
  end

  test "a request creates nothing in the register itself" do
    assert_difference -> { RegistrationRequest.count }, 1 do
      assert_no_difference [ -> { Household.count }, -> { Person.count },
                             -> { ConsentRecord.count } ] do
        post registration_requests_path, params: valid_params
      end
    end

    assert_response :created
  end

  test "a request arrives unhandled, attributed to the public site" do
    post registration_requests_path, params: valid_params

    request_record = RegistrationRequest.order(:created_at).last
    assert request_record.new_request?
    assert_nil request_record.handled_by
    assert_nil request_record.household

    version = request_record.audit_trail.last
    assert_equal "public_site", version.source_channel
  end

  test "the honeypot creates nothing and looks exactly like success" do
    post registration_requests_path, params: valid_params
    success_body = response.body

    assert_no_difference -> { RegistrationRequest.count } do
      post registration_requests_path, params: valid_params.merge(website: "http://spam.example")
    end

    # A bot must learn nothing from the response.
    assert_equal success_body, response.body
  end

  test "someone the office cannot reach is refused" do
    assert_no_difference -> { RegistrationRequest.count } do
      post registration_requests_path,
           params: { registration_request: { name: "No Contact" } }
    end

    assert_response :unprocessable_entity
  end

  test "either a phone number or a description of where to find them is enough" do
    by_phone = RegistrationRequest.new(name: "A", contact_method: "0771111111")
    by_place = RegistrationRequest.new(name: "B", location_hint: "By the borehole")

    assert by_phone.valid?
    assert by_place.valid?
  end

  test "the form never reveals whether a household is already registered" do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    existing = Household.create!(name: "Moyo homestead", principal_contact: "Sekuru Moyo",
                                 capture_source: :assisted_visit, change_reason: "capture")
    PaperTrail.request.whodunnit = nil

    post registration_requests_path,
         params: { registration_request: { name: existing.principal_contact,
                                           contact_method: "0771234567" } }

    assert_response :created
    assert_no_match(/already registered/i, response.body)
    assert_no_match(/#{Regexp.escape(existing.reference)}/, response.body)
  end

  # --- The queue -----------------------------------------------------------

  test "a request walks from new to captured, keeping the link to the record" do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    request_record = RegistrationRequest.create!(name: "Tendai Marimo",
                                                 contact_method: "0771234567",
                                                 change_reason: "from the website")

    request_record.mark_contacted!(by: users(:registrar), note: "Visiting Thursday")
    assert request_record.reload.contacted?

    household = Household.create!(name: "Marimo homestead", capture_source: :assisted_visit,
                                  change_reason: "captured from a request")
    request_record.mark_captured!(household: household, by: users(:registrar))

    request_record.reload
    assert request_record.captured?
    assert_equal household, request_record.household
    assert_equal users(:registrar), request_record.handled_by
  end

  test "a declined request keeps its reason rather than vanishing" do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    request_record = RegistrationRequest.create!(name: "Someone", contact_method: "0770000000",
                                                 change_reason: "from the website")

    request_record.decline!(by: users(:registrar), note: "Already registered under another name")

    assert request_record.reload.declined?
    assert_equal "Already registered under another name", request_record.outcome_note
    assert RegistrationRequest.exists?(request_record.id)
  end

  test "requests that went nowhere become stale so they can be cleared out" do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    fresh = RegistrationRequest.create!(name: "Recent", contact_method: "0770000001",
                                        change_reason: "from the website")
    old = RegistrationRequest.create!(name: "Forgotten", contact_method: "0770000002",
                                      change_reason: "from the website")
    old.update_columns(updated_at: (RegistrationRequest::RETENTION_DAYS + 1).days.ago)

    assert_not fresh.stale?
    assert old.reload.stale?,
           "a request holding contact details for someone who consented to nothing " \
           "must not sit here indefinitely"
  end

  test "a programme manager cannot see the queue" do
    assert Ability.new(users(:registrar)).can?(:read, RegistrationRequest)
    assert Ability.new(users(:administrator)).can?(:read, RegistrationRequest)
    assert_not Ability.new(users(:programme_manager)).can?(:read, RegistrationRequest)
  end

  test "nobody can destroy a request" do
    %i[registrar administrator programme_manager tech_admin].each do |role|
      assert_not Ability.new(users(role)).can?(:destroy, RegistrationRequest.new)
    end
  end
end
