require "test_helper"

# Keeping a normalised number alongside the free text is what lets an inbound
# message find a household — and what must not destroy a contact method that
# happens not to be a phone number.
class ContactableTest < ActiveSupport::TestCase
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
  end

  test "a household is found by however the inbound number is written" do
    household = Household.create!(name: "Moyo homestead", principal_contact: "0771234567",
                                  capture_source: :assisted_visit, change_reason: "capture")

    [ "+263771234567", "263771234567", "0771234567", "077 123 4567" ].each do |inbound|
      assert_equal household, Household.find_by_contact_number(inbound),
                   "#{inbound} should reach this household"
    end
  end

  test "an unknown number matches nothing, so it becomes a registration request" do
    Household.create!(name: "Moyo homestead", principal_contact: "0771234567",
                      capture_source: :assisted_visit, change_reason: "capture")

    assert_nil Household.find_by_contact_number("+263779999999")
  end

  test "a contact method that is not a number is kept, not discarded" do
    household = Household.create!(name: "Ncube homestead",
                                  principal_contact: "ask for Mai Ncube at the shop",
                                  capture_source: :assisted_visit, change_reason: "capture")

    assert_equal "ask for Mai Ncube at the shop", household.principal_contact
    assert_nil household.contact_number
    assert_not household.reachable_by_message?
  end

  test "the number is extracted from text around it" do
    household = Household.create!(name: "Moyo homestead",
                                  principal_contact: "Sekuru Moyo, 0771 234 567",
                                  capture_source: :assisted_visit, change_reason: "capture")

    assert_equal "+263771234567", household.contact_number
    assert household.reachable_by_message?
  end

  test "changing the contact details updates what a message would go to" do
    household = Household.create!(name: "Moyo homestead", principal_contact: "0771234567",
                                  capture_source: :assisted_visit, change_reason: "capture")

    household.update!(principal_contact: "0712345678", change_reason: "new number")

    assert_equal "+263712345678", household.reload.contact_number
    assert_nil Household.find_by_contact_number("0771234567"),
               "the old number must stop reaching this household"
  end

  test "people and registration requests are matchable too" do
    household = Household.create!(name: "Moyo homestead", capture_source: :assisted_visit,
                                  change_reason: "capture")
    person = household.people.create!(name: "Tapiwa", relationship: :head,
                                      age_band: :age_60_plus, residency_status: :resident,
                                      contact_method: "077 123 4567")
    request = RegistrationRequest.create!(name: "Tendai", contact_method: "0712345678",
                                          change_reason: "from the website")

    assert_equal person, Person.find_by_contact_number("+263771234567")
    assert_equal request, RegistrationRequest.find_by_contact_number("+263712345678")
  end

  test "with_contact_number selects only households a message can reach" do
    reachable = Household.create!(name: "Reachable", principal_contact: "0771234567",
                                  capture_source: :assisted_visit, change_reason: "capture")
    unreachable = Household.create!(name: "Unreachable", principal_contact: "ask at the shop",
                                    capture_source: :assisted_visit, change_reason: "capture")

    assert_includes Household.with_contact_number, reachable
    assert_not_includes Household.with_contact_number, unreachable
  end

  test "a phone number is not treated as a minimised field" do
    # The brief lists "contact method where available" as a Person field, so a
    # number is permitted. This asserts the governance guard does not start
    # rejecting it, which would be a false positive.
    assert_includes Person.column_names, "contact_number"
    assert_includes Household.column_names, "contact_number"
  end
end
