require "test_helper"

# The public website. The single most important property is what it does NOT
# show, so that is tested against real seeded data rather than trusted to the
# templates staying honest.
class PublicSiteTest < ActionDispatch::IntegrationTest
  # Every page a signed-out visitor can reach. New pages belong here: the leak
  # test below is only as good as this list.
  PUBLIC_PAGES = %w[/ /about /privacy /contact /payments /diaspora /services
                    /register /registry /have-your-say].freeze

  setup do
    PaperTrail.request.whodunnit = users(:administrator).id.to_s

    @household = Household.create!(name: "Moyo homestead", principal_contact: "Sekuru Moyo",
                                   location_description: "Third homestead past the borehole",
                                   capture_source: :assisted_visit, change_reason: "capture")
    @person = @household.people.create!(name: "Tapiwa Moyo", relationship: :head,
                                        age_band: :age_60_plus, residency_status: :resident)

    @campaign = MobilisationCampaign.create!(name: "Community Centre Roofing Fund",
                                             purpose: "Roof sheets for the community centre",
                                             campaign_type: :building_fund, target_amount: 5000,
                                             change_reason: "agreed")
    @campaign.approve_receiving_account!(by: users(:administrator),
                                         name: "Village Development Account",
                                         detail: "Bank 0123456789")
    @campaign.open!(by: users(:administrator))

    @contribution = Contribution.create!(mobilisation_campaign: @campaign, household: @household,
                                         contribution_kind: :money, amount: 250,
                                         change_reason: "pledged")
    receipt = @contribution.receipts.create!(payment_rail: :bank, external_reference: "BK-1",
                                             amount: 250, captured_by: users(:registrar))
    receipt.verify!(by: users(:administrator))
    @contribution.reconcile!

    ProgrammeCase.create!(household: @household, programme_type: :drought_relief,
                          change_reason: "opened")

    PaperTrail.request.whodunnit = nil
  end

  test "every public page opens without signing in" do
    PUBLIC_PAGES.each do |path|
      get path
      assert_response :success, "#{path} must be public"
    end
  end

  test "no public page leaks anything about a household or a person" do
    leaks = [ @household.name, @household.reference, @household.principal_contact,
              @household.location_description, @household.token,
              @person.name, @contribution.reference ]

    PUBLIC_PAGES.each do |path|
      get path
      leaks.each do |secret|
        assert_no_match(/#{Regexp.escape(secret)}/, response.body,
                        "#{path} leaked #{secret.truncate(30)}")
      end
    end
  end

  test "no public page mentions programme cases at all" do
    # That a family sought welfare support must not circulate.
    PUBLIC_PAGES.each do |path|
      get path
      assert_no_match(/CASE-\d{4}/, response.body)
      assert_no_match(/drought relief case/i, response.body)
    end
  end

  test "the payments page shows the ledger without naming contributors" do
    get "/payments"

    assert_response :success
    assert_match @campaign.name, response.body
    assert_match "5,000", response.body, "the target should be shown"
    assert_match "250", response.body, "the amount raised should be shown"
    assert_match "Village Development Account", response.body,
                 "the approved account is public so people pay the right place"

    # But never who gave it.
    assert_no_match(/#{Regexp.escape(@household.name)}/, response.body)
  end

  test "the payments page says plainly that contributors are not published" do
    get "/payments"

    assert_match(/never publish who gave/i, response.body)
  end

  test "the services page marks what is not built as planned" do
    get "/services"

    assert_match(/Available now/, response.body)
    assert_match(/Planned/, response.body)
    assert_match(/not built yet/i, response.body)
  end

  test "the progress bar renders its real width server side" do
    # So it is correct with JavaScript off; the Stimulus controller only animates.
    get "/payments"

    assert_match(/style="width: #{@campaign.progress_percentage}%"/, response.body)
  end

  test "old links still land somewhere" do
    # /campaigns and /trust were shared before the pages moved.
    get "/campaigns"
    assert_redirected_to "/payments"

    get "/trust"
    assert_redirected_to "/privacy"
  end

  test "no admin route is reachable without signing in" do
    [ "/admin", "/admin/households", "/admin/registration_requests",
      "/admin/programme_cases", "/admin/contributions" ].each do |path|
      get path
      assert_redirected_to new_user_session_path
    end
  end
end
