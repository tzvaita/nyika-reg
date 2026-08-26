require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "the four roles from the brief exist, in a fixed order" do
    assert_equal({ "registrar" => 0, "administrator" => 1,
                   "programme_manager" => 2, "tech_admin" => 3 }, User.roles)
  end

  test "a deactivated user cannot authenticate but is not deleted" do
    user = users(:deactivated)

    assert_not user.active_for_authentication?
    assert_equal :account_deactivated, user.inactive_message
    assert User.exists?(user.id), "deactivation must never remove the record"
  end

  test "an active user can authenticate" do
    assert users(:registrar).active_for_authentication?
  end

  test "search can never reach credential columns" do
    %w[encrypted_password reset_password_token remember_created_at].each do |column|
      assert_not_includes User.ransackable_attributes, column,
                          "#{column} must not be searchable"
    end
  end

  test "name is required" do
    user = User.new(email: "x@example.test", password: "password123", role: :registrar)
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :name
  end
end
