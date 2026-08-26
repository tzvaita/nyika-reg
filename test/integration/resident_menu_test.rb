require "test_helper"

# The resident menu from the concept deck: update household, government support,
# make a payment, my applications, my receipts, speak to the office.
class ResidentMenuTest < ActionDispatch::IntegrationTest
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s

    @household = Household.create!(name: "Moyo homestead", principal_contact: "Sekuru Moyo",
                                   location_description: "Past the borehole",
                                   capture_source: :assisted_visit, change_reason: "capture")
    @member = @household.people.create!(name: "Tanaka Moyo", relationship: :child,
                                        age_band: :age_5_17, residency_status: :resident)

    @campaign = MobilisationCampaign.create!(name: "Roofing Fund", campaign_type: :building_fund,
                                             target_amount: 5000, suggested_contribution: 10,
                                             change_reason: "agreed")
    @campaign.approve_receiving_account!(by: users(:administrator), name: "Village Account",
                                         detail: "Bank 0123456789")
    @campaign.open!(by: users(:administrator))

    PaperTrail.request.whodunnit = nil
    @token = @household.token
  end

  test "every menu page opens with the household token and no account" do
    [ household_update_path(token: @token),
      resident_support_path(token: @token),
      resident_applications_path(token: @token),
      resident_payments_path(token: @token),
      resident_receipts_path(token: @token),
      resident_office_path(token: @token) ].each do |path|
      get path
      assert_response :success, "#{path} should open for a household"
    end
  end

  test "a bogus token is refused on every menu page" do
    [ resident_support_path(token: "nope"), resident_payments_path(token: "nope"),
      resident_receipts_path(token: "nope"), resident_applications_path(token: "nope") ].each do |path|
      get path
      assert_response :not_found
    end
  end

  # --- Government support --------------------------------------------------

  test "asking for support without agreeing opens nothing" do
    assert_no_difference -> { ProgrammeCase.count } do
      post resident_support_path(token: @token), params: { programme_type: "drought_relief" }
    end

    assert_redirected_to resident_support_path(token: @token)
    assert_not @member.reload.consented_to?(:programme)
  end

  test "asking for support records consent and opens a case" do
    assert_difference -> { ProgrammeCase.count }, 1 do
      post resident_support_path(token: @token),
           params: { programme_type: "beam", beneficiary_id: @member.id, consent_given: "1" }
    end

    programme_case = @household.programme_cases.last
    assert_equal "beam", programme_case.programme_type
    assert_equal @member, programme_case.beneficiary
    assert @member.reload.consented_to?(:programme),
           "consent must be recorded, not assumed from the request"
  end

  test "consent from a support request is purpose-specific" do
    post resident_support_path(token: @token),
         params: { programme_type: "beam", beneficiary_id: @member.id, consent_given: "1" }

    @member.reload
    assert @member.consented_to?(:programme)
    assert_not @member.consented_to?(:payment),
               "agreeing to be considered for support is not agreeing to anything else"
    assert_not @member.consented_to?(:partner_contact)
  end

  test "a resident request is audited as coming from the household" do
    post resident_support_path(token: @token),
         params: { programme_type: "drought_relief", consent_given: "1" }

    version = @household.programme_cases.last.audit_trail.last
    assert_equal "resident_link", version.source_channel
    assert_equal "household:#{@household.id}", version.whodunnit
  end

  test "an unknown programme type is refused" do
    assert_no_difference -> { ProgrammeCase.count } do
      post resident_support_path(token: @token),
           params: { programme_type: "cash_for_everyone", consent_given: "1" }
    end
  end

  # --- Payments ------------------------------------------------------------

  test "the payment page shows the approved receiving account" do
    get resident_payments_path(token: @token)

    assert_response :success
    assert_match "Village Account", response.body
    assert_match "Bank 0123456789", response.body
  end

  test "a resident can pledge, and it starts as a pledge only" do
    assert_difference -> { Contribution.count }, 1 do
      post resident_payments_path(token: @token),
           params: { mobilisation_campaign_id: @campaign.id, contribution_kind: "money",
                     amount: "15", payment_method: "ecocash" }
    end

    contribution = @household.contributions.last
    assert contribution.pledged?
    assert_nil contribution.recorded_by, "a resident pledge is not staff-entered"
  end

  test "a resident cannot pledge to a campaign that is not open" do
    @campaign.close!

    assert_no_difference -> { Contribution.count } do
      post resident_payments_path(token: @token),
           params: { mobilisation_campaign_id: @campaign.id, contribution_kind: "money", amount: "15" }
    end
  end

  test "a resident cannot mark their own payment as received" do
    post resident_payments_path(token: @token),
         params: { mobilisation_campaign_id: @campaign.id, contribution_kind: "money", amount: "15" }

    contribution = @household.contributions.last
    assert_raises(ArgumentError) { contribution.reconcile! }
  end

  # --- Seeing only your own data -------------------------------------------

  test "a household sees only its own applications, pledges and receipts" do
    other = Household.create!(name: "Ncube homestead", capture_source: :assisted_visit,
                              change_reason: "capture")
    other_case = ProgrammeCase.create!(household: other, programme_type: :drought_relief,
                                       change_reason: "x")
    other_contribution = Contribution.create!(mobilisation_campaign: @campaign, household: other,
                                              contribution_kind: :money, amount: 99,
                                              change_reason: "x")

    get resident_applications_path(token: @token)
    assert_no_match(/Ncube/, response.body)
    assert_no_match(/#{other_case.reference}/, response.body)

    get resident_receipts_path(token: @token)
    assert_no_match(/Ncube/, response.body)
    # Match on the reference, not the bare amount: "99" also appears in asset
    # fingerprints, which made this assertion fail on a page that was correct.
    assert_no_match(/#{other_contribution.reference}/, response.body)
  end

  test "an unverified receipt is shown as still being checked, not hidden" do
    post resident_payments_path(token: @token),
         params: { mobilisation_campaign_id: @campaign.id, contribution_kind: "money", amount: "15" }
    contribution = @household.contributions.last
    contribution.receipts.create!(payment_rail: :ecocash, external_reference: "EC-9",
                                  amount: 15, captured_by: users(:registrar))

    get resident_receipts_path(token: @token)

    assert_response :success
    assert_match(/still checking/i, response.body)
  end
end
