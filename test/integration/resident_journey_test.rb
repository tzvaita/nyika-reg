require "test_helper"

# The resident journey: a household opens its own record from a link, with no
# account, and its changes go to the verification queue rather than going live.
class ResidentJourneyTest < ActionDispatch::IntegrationTest
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s
    @household = Household.create!(
      name: "Moyo homestead",
      principal_contact: "Sekuru Moyo",
      location_description: "Third homestead past the borehole",
      capture_source: :assisted_visit,
      change_reason: "Initial capture"
    )
    @household.people.create!(name: "Sekuru Moyo", relationship: :head,
                              age_band: :age_60_plus, residency_status: :resident)
    PaperTrail.request.whodunnit = nil
  end

  test "the landing page reveals nothing about who lives in the village" do
    get root_path

    assert_response :success
    assert_no_match(/Moyo/, response.body)
    assert_no_match(/NYK-\d{4}/, response.body)
  end

  test "a household opens its own record with its token and no account" do
    get household_update_path(token: @household.token)

    assert_response :success
    assert_match @household.name, response.body
    assert_match @household.reference, response.body
  end

  test "an unknown token is a plain 404 that reveals nothing" do
    get household_update_path(token: "not-a-real-token")

    assert_response :not_found
  end

  test "regenerating the token revokes the old link immediately" do
    old_token = @household.token
    @household.regenerate_token!

    assert_not_equal old_token, @household.reload.token

    get household_update_path(token: old_token)
    assert_response :not_found

    get household_update_path(token: @household.token)
    assert_response :success
  end

  test "a resident update returns the household to the verification queue" do
    @household.update_columns(status: Household.statuses[:verified])

    patch household_update_path(token: @household.token), params: {
      household: { principal_contact: "Mai Moyo", change_reason: "New phone number" }
    }

    @household.reload
    assert @household.pending?, "a resident edit must go back for verification"
    assert_equal "Mai Moyo", @household.principal_contact
    assert_includes Household.verification_queue, @household
  end

  test "a resident can never verify their own record" do
    patch household_update_path(token: @household.token), params: {
      household: { principal_contact: "Mai Moyo", change_reason: "New phone number" }
    }

    assert_not @household.reload.verified?
  end

  test "a resident change is audited with reason, channel and who submitted it" do
    patch household_update_path(token: @household.token), params: {
      household: { principal_contact: "Mai Moyo", change_reason: "New phone number" }
    }

    version = @household.reload.audit_trail.first

    assert_equal "New phone number", version.reason
    assert_equal "resident_link", version.source_channel,
                 "needed to tell self-service edits from assisted ones"
    assert_equal "household:#{@household.id}", version.whodunnit,
                 "the audit trail must say who submitted, not 'system'"
  end

  test "a resident cannot change their own status, reference or token" do
    original = { status: @household.status, reference: @household.reference,
                 token: @household.token }

    patch household_update_path(token: @household.token), params: {
      household: { status: "verified", reference: "NYK-9999-9999",
                   token: "chosen-by-me", principal_contact: "Mai Moyo",
                   change_reason: "trying it on" }
    }

    @household.reload
    assert_equal original[:reference], @household.reference
    assert_equal original[:token], @household.token
    assert_not @household.verified?
  end

  test "assisted capture requires a signed-in user" do
    get new_capture_household_path

    assert_redirected_to new_user_session_path
  end
end
