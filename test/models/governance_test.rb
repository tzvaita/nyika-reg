require "test_helper"

# The governance rules in the README are structural promises, not aspirations.
# This test fails if a later change quietly breaks one of them.
class GovernanceTest < ActiveSupport::TestCase
  # Anything matching these must never appear as a column anywhere in the schema.
  FORBIDDEN = {
    "national identifier" => /national_id|nat_id|id_number|passport|birth_cert/,
    "health data"         => /health|medical|diagnos|hiv|clinic/,
    "income data"         => /income|salary|wage|earnings/,
    "disability detail"   => /disabilit|impairment/,
    "land or plot claim"  => /\Aplot|_plot|title_deed|parcel|stand_number/,
    "precise location"    => /latitude|longitude|\Agps|geo_point/,
    "full date of birth"  => /date_of_birth|birth_date|\Adob\z/
  }.freeze

  # ProgrammeCase and CaseDocument are included deliberately. The brief permits
  # health, disability, children and financial data inside a programme case with
  # restricted access — but this build captures none of it, and this test is what
  # stops that changing by accident rather than by decision.
  REGISTRY_MODELS = [ Household, Person, ConsentRecord, User,
                      ProgrammeCase, CaseDocument,
                      MobilisationCampaign, Contribution, Receipt ].freeze

  test "no minimised field exists anywhere in the registry schema" do
    REGISTRY_MODELS.each do |model|
      model.column_names.each do |column|
        FORBIDDEN.each do |description, pattern|
          assert_no_match pattern, column,
                          "#{model.name}.#{column} looks like #{description}, " \
                          "which field minimisation forbids"
        end
      end
    end
  end

  test "consent is modelled as rows per purpose, not a flag" do
    assert ConsentRecord.column_names.include?("purpose")
    # Brief p6 names five: village administration, programme support,
    # communication, payment receipts and partner contact.
    assert_equal 5, ConsentRecord.purposes.size

    REGISTRY_MODELS.each do |model|
      blanket = model.column_names.grep(/\A(consented|consent_given|has_consent|opt_in)\z/)
      assert_empty blanket, "#{model.name} has a blanket consent flag"
    end
  end

  test "a programme case records what evidence was seen, never what it said" do
    # The brief allows sensitive data inside a case; this build still does not
    # hold it. A case says a document was sighted and verified — not its contents.
    forbidden = %w[diagnosis condition medical_note income_amount disability_type
                   assessment_result vulnerability_score]

    (ProgrammeCase.column_names + CaseDocument.column_names).each do |column|
      assert_not_includes forbidden, column,
                          "#{column} would put sensitive content into the registry"
    end
  end

  test "case evidence cannot be verified by whoever recorded it" do
    household = Household.create!(name: "Case governance", capture_source: :assisted_visit,
                                  change_reason: "test")
    programme_case = ProgrammeCase.create!(household: household, programme_type: :drought_relief,
                                           change_reason: "test")
    document = programme_case.case_documents.create!(document_type: :household_confirmation,
                                                     uploaded_by: users(:registrar))

    assert_raises(ArgumentError) { document.verify!(by: users(:registrar)) }

    document.verify!(by: users(:administrator))
    assert document.reload.verified?
  end

  test "the political firewall: contributions are not linked to programme cases" do
    # Both documents forbid mixing contribution flows with welfare, vulnerability
    # or government programme data. Keeping the tables unlinked is what makes that
    # structural rather than a matter of good behaviour — so no association
    # between the two may exist in either direction.
    contribution_links = Contribution.reflect_on_all_associations.map(&:name)
    case_links = ProgrammeCase.reflect_on_all_associations.map(&:name)

    assert_not_includes contribution_links, :programme_case
    assert_not_includes contribution_links, :programme_cases
    assert_not_includes case_links, :contribution
    assert_not_includes case_links, :contributions

    # And no foreign key columns joining them either.
    assert_not_includes Contribution.column_names, "programme_case_id"
    assert_not_includes ProgrammeCase.column_names, "contribution_id"
  end

  test "no role can see both casework and contributions except the administrator" do
    # The two views are kept apart so nobody can form the link "this family gave,
    # or did not give, so treat their support claim accordingly".
    registrar = Ability.new(users(:registrar))
    programme = Ability.new(users(:programme_manager))

    assert registrar.can?(:read, Contribution)
    assert_not registrar.can?(:read, ProgrammeCase)

    assert programme.can?(:read, ProgrammeCase)
    assert_not programme.can?(:read, Contribution)
  end

  test "political fundraising is not an available campaign type" do
    # Excluded from the POC until legal and governance approvals are explicit,
    # so the option is absent rather than present-and-discouraged.
    assert_not MobilisationCampaign.campaign_types.keys.any? { |t| t.match?(/politic|party|candidate|election/) }
  end

  test "the registry records payments but never holds funds" do
    # A balance or wallet column would mean the platform had become a bank, which
    # both documents rule out.
    banking = /\A(balance|wallet|float|account_balance|held_funds)\z/
    [ MobilisationCampaign, Contribution, Receipt, Household ].each do |model|
      model.column_names.each do |column|
        assert_no_match banking, column, "#{model.name}.#{column} suggests holding funds"
      end
    end
  end

  test "every registry record is auditable" do
    [ Household, Person, ConsentRecord, ProgrammeCase, CaseDocument,
      MobilisationCampaign, Contribution, Receipt ].each do |model|
      assert model.reflect_on_association(:versions).present?,
             "#{model.name} must record versions"
      assert model.new.respond_to?(:change_reason), "#{model.name} must accept a change reason"
    end
  end

  test "the versions table records actor, time, values, reason and source channel" do
    # Brief p4 defines the audit event as: actor, timestamp, action, old value,
    # new value, reason, source channel.
    %w[whodunnit created_at event object object_changes reason source_channel].each do |column|
      assert_includes PaperTrail::Version.column_names, column,
                      "the audit trail must record #{column}"
    end
  end

  test "every version is stamped with a source channel" do
    # An unlabelled version would silently distort the pilot's "residents who
    # update without assistance" figure.
    household = Household.create!(name: "Channel test", capture_source: :assisted_visit,
                                  change_reason: "test")
    assert_equal "system", household.versions.last.source_channel

    household.audit_source_channel = "resident_link"
    household.update!(principal_contact: "Someone", change_reason: "resident edit")

    assert_equal "resident_link", household.versions.last.source_channel
  end

  test "registry records are protected from deletion by association" do
    assert_equal :restrict_with_error, Household.reflect_on_association(:people).options[:dependent]
    assert_equal :restrict_with_error, Person.reflect_on_association(:consent_records).options[:dependent]
  end
end
