require "test_helper"

class PersonTest < ActiveSupport::TestCase
  setup do
    @registrar = users(:registrar)
    PaperTrail.request.whodunnit = @registrar.id.to_s
    @household = Household.create!(name: "Moyo homestead", capture_source: :assisted_visit,
                                   change_reason: "Initial capture")
  end

  def build_person(**overrides)
    @household.people.create!({
      name: "Sekuru Moyo", relationship: :head,
      age_band: :age_60_plus, residency_status: :resident
    }.merge(overrides))
  end

  test "an age band alone is enough" do
    person = build_person(age_band: :age_18_35, year_of_birth: nil)
    assert person.valid?
  end

  test "a year of birth alone is enough" do
    person = build_person(age_band: nil, year_of_birth: 1985)
    assert person.valid?
  end

  test "some age information is required" do
    person = @household.people.build(name: "Unknown", relationship: :child,
                                     residency_status: :resident)

    assert_not person.valid?
    assert_includes person.errors.attribute_names, :age_band
  end

  test "the model has no date of birth at all" do
    # FIELD MINIMISATION: a full DOB is identifying and the registry has no use
    # for it. This asserts the column was never added back.
    assert_not Person.column_names.any? { |c| c.match?(/birth_date|date_of_birth|\Adob\z/) },
               "Person must not carry a full date of birth"
  end

  test "an implausible year of birth is rejected" do
    # build, not create: create! would raise before the assertion could run.
    person = @household.people.build(name: "Future person", relationship: :child,
                                     residency_status: :resident,
                                     age_band: nil, year_of_birth: Date.current.year + 1)

    assert_not person.valid?
    assert_includes person.errors.attribute_names, :year_of_birth
  end

  test "deactivation keeps the person and their history" do
    person = build_person
    person.deactivate!(reason: "Moved to Harare")

    assert_not person.reload.active?
    assert Person.exists?(person.id)
    assert_not_includes @household.active_people, person
  end

  test "consent is answered per purpose, never as a blanket yes" do
    person = build_person
    person.consent_records.create!(purpose: :village_admin, consent_version: "v1",
                                   channel: :in_person, granted_on: Date.current)

    assert person.consented_to?(:village_admin)
    assert_not person.consented_to?(:communication),
               "consent for one purpose must not imply another"
    assert_not person.consented_to?(:programme)
    assert_not person.consented_to?(:payment)
  end

  test "a withdrawn consent no longer counts as consent" do
    person = build_person
    consent = person.consent_records.create!(purpose: :communication, consent_version: "v1",
                                             channel: :in_person, granted_on: Date.current)
    assert person.consented_to?(:communication)

    consent.withdraw!(reason: "Asked to stop being contacted")

    assert_not person.reload.consented_to?(:communication)
  end
end
