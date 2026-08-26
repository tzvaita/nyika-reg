require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  setup do
    @registrar = users(:registrar)
    @admin     = users(:administrator)
    PaperTrail.request.whodunnit = @registrar.id.to_s
  end

  def build_household(**overrides)
    Household.create!({
      name: "Moyo homestead",
      principal_contact: "Sekuru Moyo",
      location_description: "Third homestead past the borehole",
      capture_source: :assisted_visit,
      captured_by: @registrar,
      change_reason: "Initial capture"
    }.merge(overrides))
  end

  test "a new household starts as a draft and gets a readable reference" do
    household = build_household

    assert household.draft?
    assert_match(/\ANYK-\d{4}-\d{4}\z/, household.reference)
  end

  test "references are unique and increment" do
    first  = build_household
    second = build_household(name: "Ncube homestead")

    assert_not_equal first.reference, second.reference
    assert_equal first.reference.split("-").last.to_i + 1,
                 second.reference.split("-").last.to_i
  end

  test "the lifecycle runs draft to pending to verified" do
    household = build_household

    household.submit_for_verification!(reason: "Capture complete")
    assert household.reload.pending?

    household.verify!(by: @admin, reason: "Confirmed on site visit")
    household.reload

    assert household.verified?
    assert_equal @admin, household.verified_by
    assert_not_nil household.verified_at
    assert_equal Date.current, household.last_confirmed_on
  end

  test "only a pending household can be verified" do
    household = build_household

    assert household.draft?
    assert_raises(ArgumentError) { household.verify!(by: @admin) }
  end

  test "only a draft household can be submitted" do
    household = build_household
    household.submit_for_verification!(reason: "Capture complete")

    assert_raises(ArgumentError) { household.submit_for_verification! }
  end

  test "deactivation is a status flip, never a deletion" do
    household = build_household
    household.deactivate!(reason: "Household left the village")

    assert household.reload.inactive?
    assert Household.exists?(household.id), "the row must survive"
  end

  test "the queues select the right households" do
    draft = build_household
    pending = build_household(name: "Ncube homestead")
    pending.submit_for_verification!(reason: "Capture complete")

    assert_includes Household.capture_queue, draft
    assert_not_includes Household.capture_queue, pending

    assert_includes Household.verification_queue, pending
    assert_not_includes Household.verification_queue, draft
  end

  test "missing required fields are reported for the data-quality report" do
    household = build_household(principal_contact: nil, location_description: nil)

    assert_equal %w[principal_contact location_description],
                 household.missing_required_fields
    assert_not household.complete?
  end

  test "every change records actor, reason and the changed values" do
    household = build_household
    PaperTrail.request.whodunnit = @admin.id.to_s
    household.submit_for_verification!(reason: "Capture complete")

    version = household.audit_trail.first

    assert_equal "update", version.event
    assert_equal @admin.id.to_s, version.whodunnit
    assert_equal "Capture complete", version.reason
    assert_includes YAML.unsafe_load(version.object_changes).keys, "status"
    assert_not_nil version.created_at
  end

  test "a household with people cannot be destroyed" do
    household = build_household
    household.people.create!(name: "Sekuru Moyo", relationship: :head,
                             age_band: :age_60_plus, residency_status: :resident)

    assert_not household.destroy
    assert Household.exists?(household.id)
  end
end
