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

  REGISTRY_MODELS = [ Household, Person, ConsentRecord, User ].freeze

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
    assert ConsentRecord.purposes.size >= 4

    REGISTRY_MODELS.each do |model|
      blanket = model.column_names.grep(/\A(consented|consent_given|has_consent|opt_in)\z/)
      assert_empty blanket, "#{model.name} has a blanket consent flag"
    end
  end

  test "every registry record is auditable" do
    [ Household, Person, ConsentRecord ].each do |model|
      assert model.reflect_on_association(:versions).present?,
             "#{model.name} must record versions"
      assert model.new.respond_to?(:change_reason), "#{model.name} must accept a change reason"
    end
  end

  test "the versions table records actor, time, values and reason" do
    %w[whodunnit created_at object object_changes reason].each do |column|
      assert_includes PaperTrail::Version.column_names, column,
                      "the audit trail must record #{column}"
    end
  end

  test "registry records are protected from deletion by association" do
    assert_equal :restrict_with_error, Household.reflect_on_association(:people).options[:dependent]
    assert_equal :restrict_with_error, Person.reflect_on_association(:consent_records).options[:dependent]
  end
end
