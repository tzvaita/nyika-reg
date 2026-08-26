require "test_helper"

# The Ability class is the only place role is consulted, so these tests are the
# authoritative statement of who may do what.
class AbilityTest < ActiveSupport::TestCase
  def ability_for(role)
    Ability.new(users(role))
  end

  def draft   = Household.new(status: "draft")
  def pending = Household.new(status: "pending")

  test "everyone signed in can read the registry and its audit trail" do
    %i[registrar administrator programme_manager tech_admin].each do |role|
      ability = ability_for(role)
      assert ability.can?(:read, Household), "#{role} should read households"
      assert ability.can?(:read, PaperTrail::Version), "#{role} should read the audit trail"
      assert ability.can?(:read, ActiveAdmin::Page), "#{role} should reach the dashboard"
    end
  end

  test "a registrar captures but may not verify their own work" do
    ability = ability_for(:registrar)

    assert ability.can?(:create, Household)
    assert ability.can?(:update, draft)
    assert ability.can?(:submit_for_verification, draft)
    assert ability.can?(:create, Person)
    assert ability.can?(:create, ConsentRecord)

    assert_not ability.can?(:verify, pending), "verification must be a second pair of eyes"
    assert_not ability.can?(:update, User.new), "registrars must not manage accounts"
    assert_not ability.can?(:deactivate, Household.new)
  end

  test "an administrator verifies and manages accounts" do
    ability = ability_for(:administrator)

    assert ability.can?(:verify, pending)
    assert ability.can?(:update, User.new)
    assert_not ability.can?(:deactivate, Household.new),
               "deactivation is reserved for tech_admin"
  end

  test "a household can only be verified while pending" do
    ability = ability_for(:administrator)

    assert ability.can?(:verify, pending)
    assert_not ability.can?(:verify, draft)
    assert_not ability.can?(:verify, Household.new(status: "verified"))
  end

  test "a programme manager reads everything and changes nothing" do
    ability = ability_for(:programme_manager)

    assert ability.can?(:read, Household)
    assert_not ability.can?(:create, Household)
    assert_not ability.can?(:update, draft)
    assert_not ability.can?(:verify, pending)
    assert_not ability.can?(:create, ConsentRecord)
    assert_not ability.can?(:withdraw, ConsentRecord.new)
    assert_not ability.can?(:update, User.new)
  end

  test "only a tech admin may deactivate" do
    assert ability_for(:tech_admin).can?(:deactivate, Household.new)

    %i[registrar administrator programme_manager].each do |role|
      assert_not ability_for(role).can?(:deactivate, Household.new),
                 "#{role} must not be able to deactivate"
    end
  end

  test "no role may destroy anything, ever" do
    %i[registrar administrator programme_manager tech_admin].each do |role|
      ability = ability_for(role)
      [ Household, Person, ConsentRecord, User ].each do |klass|
        assert_not ability.can?(:destroy, klass.new),
                   "#{role} must not be able to destroy #{klass}"
      end
    end
  end

  test "a deactivated user has no abilities at all" do
    ability = Ability.new(users(:deactivated))

    assert_not ability.can?(:read, Household)
    assert_not ability.can?(:create, Household)
  end

  test "a signed-out visitor has no abilities at all" do
    ability = Ability.new(nil)

    assert_not ability.can?(:read, Household)
    assert_not ability.can?(:read, ActiveAdmin::Page)
  end
end
