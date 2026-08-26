require "test_helper"

class PilotReportTest < ActiveSupport::TestCase
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    @report = PilotReport.new
  end

  def build_household(**overrides)
    Household.create!({
      name: "Moyo homestead",
      principal_contact: "Sekuru Moyo",
      location_description: "Third homestead past the borehole",
      capture_source: :assisted_visit,
      change_reason: "Initial capture"
    }.merge(overrides))
  end

  test "duplicate detection matches across case and spacing" do
    first  = build_household(name: "Sibanda homestead", location_description: "Near the dip tank")
    second = build_household(name: "  SIBANDA   Homestead ", location_description: "near the dip tank")

    groups = @report.duplicate_household_groups

    assert_equal 1, groups.size
    assert_equal [ first.id, second.id ].sort, groups.first.map(&:id).sort
  end

  test "households with genuinely different locations are not flagged" do
    build_household(name: "Sibanda homestead", location_description: "Near the dip tank")
    build_household(name: "Sibanda homestead", location_description: "Beyond the river")

    assert_empty @report.duplicate_household_groups,
                 "two families can share a name; only name AND location together suggest a duplicate"
  end

  test "deactivated households are left out of duplicate detection" do
    build_household(name: "Sibanda homestead", location_description: "Near the dip tank")
    old = build_household(name: "Sibanda homestead", location_description: "Near the dip tank")
    old.deactivate!(reason: "merged")

    assert_empty @report.duplicate_household_groups
  end

  test "missing required fields are reported per household" do
    incomplete = build_household(name: "Dube homestead", principal_contact: nil,
                                 location_description: nil)

    row = @report.households_missing_fields.find { |household, _| household == incomplete }

    assert_not_nil row
    assert_equal %w[principal_contact location_description], row.last
  end

  test "households with no members and people with no consent are reported" do
    empty = build_household(name: "Empty homestead")
    peopled = build_household(name: "Peopled homestead")
    person = peopled.people.create!(name: "Someone", relationship: :head,
                                    age_band: :age_18_35, residency_status: :resident)

    assert_includes @report.households_without_members, empty
    assert_not_includes @report.households_without_members, peopled
    assert_includes @report.people_without_consent, person
  end

  test "consent is reported per purpose, including the withdrawn ones" do
    household = build_household
    person = household.people.create!(name: "Someone", relationship: :head,
                                      age_band: :age_18_35, residency_status: :resident,
                                      consent_purposes: %w[village_admin communication])
    person.update!(consent_purposes: %w[village_admin], change_reason: "changed mind")

    rows = @report.consent_by_purpose

    assert_equal ConsentRecord.purposes.keys, rows.map { |r| r[:purpose] },
                 "all five purposes must appear, including ones nobody agreed to"

    village = rows.find { |r| r[:purpose] == "village_admin" }
    comms   = rows.find { |r| r[:purpose] == "communication" }

    assert_equal 1, village[:active]
    assert_equal 0, comms[:active]
    assert_equal 1, comms[:withdrawn]
  end

  test "the update rate separates resident edits from assisted ones" do
    household = build_household

    household.audit_source_channel = "assisted"
    household.update!(principal_contact: "Changed by staff", change_reason: "staff edit")

    household.audit_source_channel = "resident_link"
    household.update!(principal_contact: "Changed by household", change_reason: "resident edit")

    rate = @report.update_rate

    assert_equal 1, rate[:resident]
    assert_equal 1, rate[:assisted]
    assert_equal 50.0, rate[:percentage]
  end

  test "the update rate is zero rather than dividing by zero when nothing has changed" do
    assert_equal 0.0, PilotReport.new.update_rate[:percentage]
  end

  test "capture and verification timings come from the audit trail" do
    household = build_household
    household.versions.first.update_columns(created_at: 40.minutes.ago)

    household.submit_for_verification!(reason: "capture complete")
    household.versions.last.update_columns(created_at: 30.minutes.ago)

    household.verify!(by: users(:administrator), reason: "checked")
    household.versions.last.update_columns(created_at: 10.minutes.ago)

    assert_in_delta 10.0, @report.average_capture_minutes, 0.5
    assert_in_delta 20.0, @report.average_verification_minutes, 0.5
  end

  test "timings report nothing rather than zero when there is no data" do
    assert_nil PilotReport.new.average_capture_minutes
    assert_nil PilotReport.new.average_verification_minutes
  end
end
