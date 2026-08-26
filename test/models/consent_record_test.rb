require "test_helper"

class ConsentRecordTest < ActiveSupport::TestCase
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    household = Household.create!(name: "Moyo homestead", capture_source: :assisted_visit,
                                  change_reason: "Initial capture")
    @person = household.people.create!(name: "Sekuru Moyo", relationship: :head,
                                       age_band: :age_60_plus, residency_status: :resident)
  end

  def build_consent(**overrides)
    @person.consent_records.create!({
      purpose: :village_admin, consent_version: "v1",
      channel: :in_person, granted_on: Date.current
    }.merge(overrides))
  end

  test "the four purposes from the brief are all separately recordable" do
    assert_equal %w[village_admin communication programme payment],
                 ConsentRecord.purposes.keys
  end

  test "there is no blanket consent column anywhere" do
    forbidden = ConsentRecord.column_names.grep(/\A(consented|consent_given|has_consent|opt_in)\z/)
    assert_empty forbidden, "consent must be per purpose, not a single flag"
  end

  test "the wording version and channel are recorded" do
    consent = build_consent(consent_version: "v2", channel: :paper_form)

    assert_equal "v2", consent.consent_version
    assert_equal "paper_form", consent.channel
  end

  test "a consent version is required" do
    consent = @person.consent_records.build(purpose: :payment, channel: :in_person,
                                            granted_on: Date.current)
    assert_not consent.valid?
    assert_includes consent.errors.attribute_names, :consent_version
  end

  test "withdrawal is recorded rather than deleted" do
    consent = build_consent
    consent.withdraw!(reason: "Withdrew at village meeting", note: "Asked in person")

    consent.reload
    assert consent.withdrawn?
    assert_not_nil consent.withdrawn_at
    assert_equal "Asked in person", consent.withdrawal_note
    assert ConsentRecord.exists?(consent.id), "the row must survive withdrawal"
    assert_includes ConsentRecord.withdrawn, consent
    assert_not_includes ConsentRecord.active, consent
  end

  test "withdrawing twice does not overwrite the original withdrawal" do
    consent = build_consent
    consent.withdraw!(reason: "Withdrew")
    first_time = consent.reload.withdrawn_at

    consent.withdraw!(reason: "Again")

    assert_equal first_time, consent.reload.withdrawn_at
  end

  test "withdrawal is audited with a reason" do
    consent = build_consent
    consent.withdraw!(reason: "Withdrew at village meeting")

    version = consent.audit_trail.first
    assert_equal "Withdrew at village meeting", version.reason
  end
end
