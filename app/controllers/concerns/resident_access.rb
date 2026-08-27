# Shared by every page a resident reaches, however they got there.
#
# There are two doors, and they are not equally strong:
#
#   * A PIN SESSION — phone number plus a PIN the village office issued. This is
#     the real credential.
#   * A TOKEN LINK — /h/<token>. Once a household has a PIN this only pre-fills
#     the number and sends them to sign in; it grants nothing on its own. Before
#     a PIN exists it still opens the record, so links already sent keep working.
#
# Either way the household is identified explicitly and every page is scoped to
# THAT household — a resident can never see another family's record. Changes are
# stamped source_channel "resident_link" and attributed to the household, so the
# audit trail can answer "who submitted this" without inventing a user.
module ResidentAccess
  extend ActiveSupport::Concern
  include ResidentSession

  included do
    # The token is unguessable, but the endpoint is public, so brute-forcing it
    # should at least be slow. Database-backed cache means this now holds across
    # processes rather than being per-process memory.
    rate_limit to: 60, within: 1.minute, name: "resident_pages",
               with: -> { head :too_many_requests }

    before_action :load_household
    before_action :require_own_pin
  end

  private

  # PIN session first, then a token — and a token only opens a household that
  # has no PIN yet.
  def load_household
    @household = resident_household || household_from_token

    return if @household

    if params[:token].blank?
      # No link and no session: they came to a household page directly, or their
      # session lapsed. Send them to sign in rather than a bare 404.
      redirect_to registry_path, alert: "Please sign in to open your household."
    elsif (needs_pin = Household.find_by(token: params[:token]))
      # They have the link but the household now has a PIN. Send them to sign in
      # with the number filled in, rather than refusing flatly.
      redirect_to registry_path(token: needs_pin.token),
                  notice: "Please enter your PIN to open your household."
    else
      # An unknown or revoked token stays a plain 404, revealing nothing about
      # whether that household exists.
      head :not_found
    end
  end

  # A household signed in with the PIN the office issued must choose their own
  # before anything else is reachable. Without this they could sign in and simply
  # navigate past the change screen, leaving a PIN the registrar also knows.
  def require_own_pin
    return unless @household&.pin_temporary?
    # Only meaningful for a PIN session: a token-only household has no PIN yet.
    return unless resident_household

    redirect_to change_pin_path,
                notice: "Please choose your own PIN before carrying on."
  end

  # Deliberately not find_by!: an unknown token and a token for a household that
  # now has a PIN are handled differently above.
  def household_from_token
    return nil if params[:token].blank?

    household = Household.find_by(token: params[:token])
    return nil if household.nil? || household.pin_set?

    household
  end

  def token
    params[:token]
  end
end
