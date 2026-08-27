require "test_helper"

# The resident front door: phone number plus a PIN the village office issued.
#
# The point of the PIN is that holding the link is no longer enough, so most of
# this tests what is refused rather than what works.
class PinPortalTest < ActionDispatch::IntegrationTest
  setup do
    PaperTrail.request.whodunnit = users(:registrar).id.to_s

    @household = Household.create!(name: "Moyo homestead",
                                   principal_contact: "0771234567",
                                   location_description: "Past the borehole",
                                   capture_source: :assisted_visit,
                                   change_reason: "capture")
    @household.people.create!(name: "Tapiwa Moyo", relationship: :head,
                              age_band: :age_60_plus, residency_status: :resident)

    @pin = @household.issue_temporary_pin!(by: users(:registrar))

    PaperTrail.request.whodunnit = nil
  end

  def sign_in_household(number: @household.contact_number, pin: @pin)
    post registry_path, params: { contact_number: number, pin: pin }
  end

  # --- signing in ----------------------------------------------------------

  test "the number is accepted however it is written" do
    [ "+263771234567", "0771234567", "077 123 4567", "263771234567" ].each do |written|
      sign_in_household(number: written)
      assert_redirected_to change_pin_path, "#{written} should sign this household in"
      delete registry_signout_path
    end
  end

  test "a wrong PIN is refused" do
    sign_in_household(pin: "000000")

    assert_redirected_to registry_path
    follow_redirect!
    assert_match(/could not sign you in/i, response.body)
  end

  test "an unknown number and a wrong PIN give the same answer" do
    sign_in_household(number: "+263779999999", pin: "123456")
    unknown = flash[:alert]

    sign_in_household(pin: "000000")
    wrong_pin = flash[:alert]

    # A different message would let anyone test which numbers are registered.
    assert_equal unknown, wrong_pin
  end

  test "repeated wrong PINs lock the household, and the right PIN is then refused" do
    Household::MAX_PIN_ATTEMPTS.times { sign_in_household(pin: "000000") }

    assert @household.reload.pin_locked?

    sign_in_household
    assert_redirected_to registry_path
    follow_redirect!
    assert_match(/locked/i, response.body)
  end

  # --- the temporary PIN ---------------------------------------------------

  test "a temporary PIN must be changed before anything else opens" do
    sign_in_household
    assert_redirected_to change_pin_path

    # And it cannot simply be navigated past.
    get household_dashboard_path
    assert_redirected_to change_pin_path
  end

  test "choosing your own PIN clears the temporary flag and opens the pages" do
    sign_in_household
    patch change_pin_path, params: { pin: "445566", pin_confirmation: "445566" }

    assert_redirected_to household_dashboard_path
    @household.reload
    assert_not @household.pin_temporary?
    assert @household.verify_pin("445566")

    get household_dashboard_path
    assert_response :success
  end

  test "a mismatched confirmation is refused" do
    sign_in_household
    patch change_pin_path, params: { pin: "445566", pin_confirmation: "445567" }

    assert_response :unprocessable_entity
    assert @household.reload.pin_temporary?
  end

  test "a PIN shorter than six digits is refused" do
    sign_in_household
    patch change_pin_path, params: { pin: "123", pin_confirmation: "123" }

    assert_response :unprocessable_entity
  end

  # --- no self-service anywhere --------------------------------------------

  test "the PIN screen cannot be reached without a session" do
    get change_pin_path
    assert_redirected_to registry_path

    patch change_pin_path, params: { pin: "445566", pin_confirmation: "445566" }
    assert_redirected_to registry_path
  end

  test "there is no route that resets a PIN from a phone number alone" do
    # The whole design rests on this: if a number could reset a PIN, the number
    # would be the only real credential.
    reset_like = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
                      .grep(/registry/)
                      .grep(/reset|forgot|recover/)

    assert_empty reset_like
  end

  # --- the token stops being a credential ----------------------------------

  test "a link to a household WITH a PIN asks for it" do
    get household_update_path(token: @household.token)

    assert_redirected_to registry_path(token: @household.token)
  end

  test "a link to a household WITHOUT a PIN still opens, so old links keep working" do
    @household.update_columns(pin_digest: nil, pin_temporary: false)

    get household_update_path(token: @household.token)

    assert_response :success
  end

  test "an unknown token is still a plain 404" do
    get household_update_path(token: "not-a-real-token")

    assert_response :not_found
  end

  # --- sessions ------------------------------------------------------------

  test "signing out ends the session" do
    sign_in_household
    patch change_pin_path, params: { pin: "445566", pin_confirmation: "445566" }
    get household_dashboard_path
    assert_response :success

    delete registry_signout_path

    get household_dashboard_path
    assert_redirected_to registry_path
  end

  test "one household's session never reaches another's record" do
    other = Household.create!(name: "Ncube homestead", principal_contact: "0712345678",
                              capture_source: :assisted_visit, change_reason: "capture")
    other_pin = other.issue_temporary_pin!(by: users(:registrar))

    post registry_path, params: { contact_number: other.contact_number, pin: other_pin }
    patch change_pin_path, params: { pin: "778899", pin_confirmation: "778899" }

    get household_dashboard_path
    assert_response :success
    assert_match other.reference, response.body
    assert_no_match(/#{Regexp.escape(@household.reference)}/, response.body)
  end

  test "a resident page reached with no session and no token sends you to sign in" do
    get household_dashboard_path

    assert_redirected_to registry_path
  end
end
