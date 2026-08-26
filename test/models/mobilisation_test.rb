require "test_helper"

class MobilisationTest < ActiveSupport::TestCase
  setup do
    @admin = users(:administrator)
    @registrar = users(:registrar)
    PaperTrail.request.whodunnit = @admin.id.to_s

    @household = Household.create!(name: "Moyo homestead", capture_source: :assisted_visit,
                                   change_reason: "capture")
    @campaign = MobilisationCampaign.create!(
      name: "Community Centre Roofing Fund", campaign_type: :building_fund,
      target_amount: 5000, suggested_contribution: 10, change_reason: "Agreed at a meeting"
    )
  end

  def approve_and_open
    @campaign.approve_receiving_account!(by: @admin, name: "Village Development Account",
                                         detail: "Bank 0123456789")
    @campaign.open!(by: @admin)
  end

  def money_contribution(amount: 10, household: @household)
    Contribution.create!(mobilisation_campaign: @campaign, household: household,
                         contribution_kind: :money, amount: amount,
                         payment_method: :ecocash, recorded_by: @registrar,
                         change_reason: "Pledged")
  end

  # --- Where the money goes ------------------------------------------------

  test "a campaign cannot open until its receiving account is approved" do
    assert_not @campaign.receiving_account_approved?
    assert_raises(ArgumentError) { @campaign.open!(by: @admin) }
    assert @campaign.reload.draft?
  end

  test "contributions cannot be recorded against a campaign that is not open" do
    contribution = Contribution.new(mobilisation_campaign: @campaign, household: @household,
                                    contribution_kind: :money, amount: 10)

    assert_not contribution.valid?
    assert_includes contribution.errors.attribute_names, :mobilisation_campaign
  end

  test "an approved receiving account opens the campaign" do
    approve_and_open

    assert @campaign.reload.open?
    assert_equal @admin, @campaign.approved_by
    assert_not_nil @campaign.approved_at
  end

  # --- Reconciliation ------------------------------------------------------

  test "a contribution cannot be reconciled without a verified receipt" do
    approve_and_open
    contribution = money_contribution

    assert_raises(ArgumentError) { contribution.reconcile! }

    contribution.receipts.create!(payment_rail: :ecocash, external_reference: "EC-1",
                                  amount: 10, captured_by: @registrar)

    assert_raises(ArgumentError, "an unverified receipt must not be enough") do
      contribution.reconcile!
    end
  end

  test "whoever captured a receipt cannot verify it" do
    approve_and_open
    receipt = money_contribution.receipts.create!(payment_rail: :ecocash,
                                                  external_reference: "EC-1", amount: 10,
                                                  captured_by: @registrar)

    assert_raises(ArgumentError) { receipt.verify!(by: @registrar) }

    receipt.verify!(by: @admin)
    assert receipt.reload.verified?
  end

  test "a verified receipt for the full amount reconciles the contribution" do
    approve_and_open
    contribution = money_contribution
    receipt = contribution.receipts.create!(payment_rail: :ecocash, external_reference: "EC-1",
                                            amount: 10, captured_by: @registrar)
    receipt.verify!(by: @admin)

    contribution.reconcile!

    assert contribution.reload.reconciled?
    assert_equal 10, @campaign.received_amount
  end

  test "a receipt that does not match the pledge is refused, not quietly accepted" do
    approve_and_open
    contribution = money_contribution(amount: 50)
    receipt = contribution.receipts.create!(payment_rail: :bank, external_reference: "BK-1",
                                            amount: 20, captured_by: @registrar)
    receipt.verify!(by: @admin)

    error = assert_raises(ArgumentError) { contribution.reconcile! }
    assert_match(/exception/, error.message)

    contribution.flag_exception!(note: "Paid 20 of 50 pledged")
    assert contribution.reload.exception?
    assert_equal 50, @campaign.exception_amount
  end

  test "a cash receipt must carry proof" do
    approve_and_open
    contribution = money_contribution

    receipt = contribution.receipts.build(payment_rail: :cash_collector, amount: 10,
                                          captured_by: @registrar)
    assert_not receipt.valid?
    assert_includes receipt.errors.attribute_names, :proof_link

    receipt.proof_link = "https://storage.example/slip-1.jpg"
    assert receipt.valid?
  end

  # --- The ledger ----------------------------------------------------------

  test "materials and labour are counted, never priced" do
    approve_and_open
    Contribution.create!(mobilisation_campaign: @campaign, household: @household,
                         contribution_kind: :labour, item_description: "Two days roofing",
                         change_reason: "Pledged")

    assert_equal 0, @campaign.received_amount,
                 "donated labour must not be converted into a cash figure"
    assert_equal({ "labour" => 1 }, @campaign.in_kind_summary)
  end

  test "money contributions require an amount and in-kind ones a description" do
    approve_and_open

    no_amount = Contribution.new(mobilisation_campaign: @campaign, household: @household,
                                 contribution_kind: :money)
    assert_not no_amount.valid?

    no_description = Contribution.new(mobilisation_campaign: @campaign, household: @household,
                                      contribution_kind: :materials)
    assert_not no_description.valid?
  end

  test "the ledger reports target, received, pending, exceptions and outstanding" do
    approve_and_open
    paid = money_contribution(amount: 100)
    receipt = paid.receipts.create!(payment_rail: :bank, external_reference: "BK-9",
                                    amount: 100, captured_by: @registrar)
    receipt.verify!(by: @admin)
    paid.reconcile!

    money_contribution(amount: 40) # still pledged

    assert_equal 100, @campaign.received_amount
    assert_equal 40, @campaign.pending_amount
    assert_equal 4900, @campaign.outstanding_amount
    assert_equal 2.0, @campaign.progress_percentage
  end

  test "the outstanding list names households that have reconciled nothing" do
    approve_and_open
    other = Household.create!(name: "Ncube homestead", capture_source: :assisted_visit,
                              change_reason: "capture")
    contribution = money_contribution
    receipt = contribution.receipts.create!(payment_rail: :ecocash, external_reference: "EC-2",
                                            amount: 10, captured_by: @registrar)
    receipt.verify!(by: @admin)
    contribution.reconcile!

    outstanding = @campaign.households_outstanding

    assert_includes outstanding, other
    assert_not_includes outstanding, @household
  end

  test "nothing in mobilisation can be destroyed" do
    approve_and_open
    contribution = money_contribution
    contribution.receipts.create!(payment_rail: :ecocash, external_reference: "EC-3",
                                  amount: 10, captured_by: @registrar)

    assert_not contribution.destroy
    assert_not @campaign.destroy
  end
end
