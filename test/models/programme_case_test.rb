require "test_helper"

class ProgrammeCaseTest < ActiveSupport::TestCase
  setup do
    @registrar = users(:registrar)
    @admin     = users(:administrator)
    PaperTrail.request.whodunnit = @registrar.id.to_s

    @household = Household.create!(name: "Moyo homestead", principal_contact: "Sekuru Moyo",
                                   location_description: "Past the borehole",
                                   capture_source: :assisted_visit, change_reason: "capture")
    @child = @household.people.create!(name: "Tanaka Moyo", relationship: :child,
                                       age_band: :age_5_17, residency_status: :resident)
  end

  def open_case(**overrides)
    ProgrammeCase.create!({ household: @household, beneficiary: @child,
                            programme_type: :beam, opened_by: @registrar,
                            change_reason: "Household asked about school fees" }.merge(overrides))
  end

  def complete_evidence(programme_case)
    programme_case.required_document_types.each do |type|
      document = programme_case.case_documents.create!(document_type: type, uploaded_by: @registrar)
      document.verify!(by: @admin)
    end
  end

  test "a new case gets a readable reference and starts as identified" do
    programme_case = open_case

    assert_match(/\ACASE-\d{4}-\d{4}\z/, programme_case.reference)
    assert programme_case.identified?
    assert_equal Date.current, programme_case.opened_on
  end

  test "a beneficiary must belong to the household the case is for" do
    other = Household.create!(name: "Ncube homestead", capture_source: :assisted_visit,
                              change_reason: "capture")
    stranger = other.people.create!(name: "Someone Else", relationship: :head,
                                    age_band: :age_36_59, residency_status: :resident)

    programme_case = ProgrammeCase.new(household: @household, beneficiary: stranger,
                                       programme_type: :beam)

    assert_not programme_case.valid?
    assert_includes programme_case.errors.attribute_names, :beneficiary
  end

  test "a case cannot be submitted without consent to be considered for programmes" do
    programme_case = open_case
    complete_evidence(programme_case)
    @household.update_columns(status: Household.statuses[:verified])

    assert_not programme_case.consent_present?
    assert_includes programme_case.blockers.join(" "), "Consent"
    assert_not programme_case.submittable?
    assert_raises(ArgumentError) { programme_case.submit!(by: @admin) }
  end

  test "a case cannot be submitted while evidence is missing" do
    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    @household.update_columns(status: Household.statuses[:verified])
    programme_case = open_case

    assert_not programme_case.evidence_complete?
    assert_not programme_case.submittable?
  end

  test "a case cannot be submitted while the household is unverified" do
    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    programme_case = open_case
    complete_evidence(programme_case)

    assert_includes programme_case.blockers.join(" "), "not verified"
    assert_not programme_case.submittable?
  end

  test "only verified evidence counts towards completeness" do
    programme_case = open_case
    programme_case.required_document_types.each do |type|
      programme_case.case_documents.create!(document_type: type, uploaded_by: @registrar)
    end

    assert_not programme_case.evidence_complete?,
               "evidence nobody has confirmed must not count"
  end

  test "a fully prepared case submits and records who sent it" do
    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    @household.update_columns(status: Household.statuses[:verified])
    programme_case = open_case
    complete_evidence(programme_case)

    assert_empty programme_case.blockers
    programme_case.submit!(by: @admin)

    assert programme_case.reload.submitted?
    assert_equal @admin, programme_case.submitted_by
    assert_not_nil programme_case.submitted_at
  end

  test "an outcome is recorded, and closes the case" do
    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    @household.update_columns(status: Household.statuses[:verified])
    programme_case = open_case
    complete_evidence(programme_case)
    programme_case.submit!(by: @admin)

    programme_case.record_outcome!(outcome: :approved, note: "Place granted")

    assert programme_case.reload.closed?
    assert_equal "approved", programme_case.outcome
    assert_equal "Place granted", programme_case.outcome_note
  end

  test "the stage follows the case's actual state" do
    programme_case = open_case
    programme_case.refresh_stage!
    assert programme_case.awaiting_consent?

    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    programme_case.refresh_stage!
    assert programme_case.gathering_evidence?

    complete_evidence(programme_case)
    programme_case.refresh_stage!
    assert programme_case.ready_to_submit?
  end

  test "eligibility notes are prompts, not refusals" do
    childless = Household.create!(name: "Childless homestead", capture_source: :assisted_visit,
                                  change_reason: "capture")
    childless.people.create!(name: "Adult", relationship: :head, age_band: :age_36_59,
                             residency_status: :resident)
    programme_case = ProgrammeCase.create!(household: childless, programme_type: :beam,
                                           change_reason: "asked")

    assert_includes programme_case.eligibility_notes.join(" "), "school-age"
    assert_not programme_case.likely_eligible?
    # The case still exists and can still proceed: the programme office decides.
    assert programme_case.persisted?
  end

  test "a case for the whole household needs consent from every member" do
    other_member = @household.people.create!(name: "Rudo Moyo", relationship: :spouse,
                                             age_band: :age_36_59, residency_status: :resident)
    programme_case = open_case(beneficiary: nil, programme_type: :drought_relief)

    assert_equal @household.active_people.count, programme_case.people_needing_consent.size

    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    assert_not programme_case.consent_present?, "one member agreeing is not the household agreeing"

    [ other_member ].each { |p| p.update!(consent_purposes: %w[programme], change_reason: "agreed") }
    @household.active_people.each { |p| p.update!(consent_purposes: %w[programme], change_reason: "agreed") }

    assert programme_case.reload.consent_present?
  end

  test "cases are never destroyed" do
    programme_case = open_case
    programme_case.case_documents.create!(document_type: :household_confirmation,
                                          uploaded_by: @registrar)

    assert_not programme_case.destroy
    assert ProgrammeCase.exists?(programme_case.id)
  end

  test "every case change is audited with a reason" do
    programme_case = open_case
    @child.update!(consent_purposes: %w[programme], change_reason: "agreed")
    programme_case.refresh_stage!(reason: "Consent received")

    version = programme_case.audit_trail.first
    assert_equal "Consent received", version.reason
    assert_not_nil version.whodunnit
  end
end
