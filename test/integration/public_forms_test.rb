require "test_helper"

# The two things the public can create from the village site: a comment, and a
# payment reference. Neither may write into the register itself.
class PublicFormsTest < ActionDispatch::IntegrationTest
  setup do
    PaperTrail.request.whodunnit = users(:administrator).id.to_s

    @household = Household.create!(name: "Moyo homestead", principal_contact: "0771234567",
                                   capture_source: :assisted_visit, change_reason: "capture")

    @campaign = MobilisationCampaign.create!(name: "Community Centre Roofing Fund",
                                             campaign_type: :building_fund, target_amount: 5000,
                                             change_reason: "agreed")
    @campaign.approve_receiving_account!(by: users(:administrator),
                                         name: "Village Development Account",
                                         detail: "Bank 0123456789")
    @campaign.open!(by: users(:administrator))

    PaperTrail.request.whodunnit = nil
  end

  # --- Have your say -------------------------------------------------------

  test "a comment can be left without a name or a number" do
    assert_difference -> { Feedback.count }, 1 do
      post feedbacks_path, params: {
        feedback: { category: "village_services", message: "The borehole is broken." }
      }
    end

    comment = Feedback.order(:created_at).last
    assert comment.anonymous?
    assert_not comment.contactable?
    assert comment.new_comment?
    assert_response :created
  end

  test "a comment creates nothing in the register" do
    assert_no_difference [ -> { Household.count }, -> { Person.count },
                           -> { ConsentRecord.count } ] do
      post feedbacks_path, params: {
        feedback: { category: "the_register", message: "A question about consent." }
      }
    end
  end

  test "the honeypot creates nothing and looks like success" do
    post feedbacks_path, params: {
      feedback: { category: "village_services", message: "Real comment." }
    }
    success = response.body

    assert_no_difference -> { Feedback.count } do
      post feedbacks_path, params: {
        feedback: { category: "village_services", message: "Spam." },
        website: "http://spam.example"
      }
    end

    assert_equal success, response.body
  end

  test "an empty comment is refused" do
    assert_no_difference -> { Feedback.count } do
      post feedbacks_path, params: { feedback: { category: "village_services", message: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "a comment is audited as coming from the public site" do
    post feedbacks_path, params: {
      feedback: { category: "payments", message: "A payment was not confirmed." }
    }

    assert_equal "public_site", Feedback.order(:created_at).last.audit_trail.last.source_channel
  end

  # --- Payment references --------------------------------------------------

  def create_reference(**overrides)
    post payment_references_path, params: {
      contribution: {
        mobilisation_campaign_id: @campaign.id, origin: "local", amount: "25",
        payment_method: "ecocash", contributor_name: "A Giver",
        contributor_contact: "0779998888"
      }.merge(overrides)
    }
  end

  test "a reference is created as a pledge, confirming nothing" do
    assert_difference -> { Contribution.count }, 1 do
      create_reference
    end

    contribution = Contribution.order(:created_at).last
    assert contribution.pledged?
    assert_nil contribution.recorded_by, "a public reference is not staff-entered"
    assert_response :created
    assert_match contribution.reference, response.body
  end

  test "the approved account is shown with the reference" do
    create_reference

    assert_match "Village Development Account", response.body
    assert_match "Bank 0123456789", response.body
  end

  test "a number the register knows attaches the payment to that household" do
    create_reference(contributor_contact: "0771234567")

    assert_equal @household, Contribution.order(:created_at).last.household
  end

  test "a number the register does not know is still accepted, unattached" do
    create_reference(origin: "diaspora", payment_method: "worldremit",
                     contributor_contact: "+447700900123")

    contribution = Contribution.order(:created_at).last
    assert_nil contribution.household
    assert contribution.origin_diaspora?
    assert_equal "worldremit", contribution.payment_method
  end

  test "every route the pages offer is one the model accepts" do
    # These drifted apart once: the diaspora page offered routes the enum had
    # never heard of, so every diaspora reference silently failed.
    (Contribution::LOCAL_METHODS + Contribution::DIASPORA_METHODS).each do |method|
      assert Contribution.payment_methods.key?(method), "#{method} is offered but not valid"
    end
  end

  test "a reference cannot be created against a closed collection" do
    @campaign.close!

    assert_no_difference -> { Contribution.count } do
      create_reference
    end

    assert_redirected_to payments_path
  end

  test "someone unidentifiable is refused" do
    # Without a household or a name, an arriving payment could never be matched.
    assert_no_difference -> { Contribution.count } do
      create_reference(contributor_name: "", contributor_contact: "")
    end
  end

  test "a public reference never appears on the public pages" do
    create_reference(contributor_name: "Very Identifiable Person")

    get "/payments"
    assert_no_match(/Very Identifiable Person/, response.body)

    get "/diaspora"
    assert_no_match(/Very Identifiable Person/, response.body)
  end
end
