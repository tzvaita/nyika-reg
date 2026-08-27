module Resident
  # The resident front door: phone number + PIN.
  #
  # There is deliberately NO route here that sets or resets a PIN from a phone
  # number alone. A PIN is issued by the village office, in person. If anyone who
  # knew a number could claim one, the number would be the only real credential —
  # which is the weakness the PIN exists to fix.
  class SessionsController < ApplicationController
    layout "public"

    include ResidentSession

    # Six digits against a known number is guessable given enough tries. The
    # per-household lockout is the main defence; this stops one client working
    # through many households. Rails.cache is database-backed, so it holds
    # across processes.
    rate_limit to: 10, within: 5.minutes, only: :create,
               with: -> { redirect_to registry_path,
                          alert: "Too many attempts. Please wait a few minutes, or speak to the village office." }

    def new
      # A token in the URL only pre-fills the number — it grants nothing.
      @household_hint = Household.find_by(token: params[:token])&.contact_number if params[:token].present?
      redirect_to household_dashboard_path if resident_household
    end

    def create
      household = Household.find_by_contact_number(params[:contact_number])

      # One message whether the number is unknown or the PIN is wrong: a
      # different answer would let anyone test which numbers are registered.
      unless household&.verify_pin(params[:pin].to_s)
        return redirect_to registry_path,
                           alert: refusal_message(household)
      end

      session[:resident_household_id] = household.id
      session[:resident_signed_in_at] = Time.current.to_i

      redirect_to household.pin_temporary? ? change_pin_path : household_dashboard_path
    end

    def destroy
      reset_resident_session
      redirect_to registry_path, notice: "You have been signed out."
    end

    private

    def refusal_message(household)
      return "That household is locked for a short while after too many wrong PINs. " \
             "Please wait, or speak to the village office." if household&.pin_locked?

      "We could not sign you in. Check the number and PIN, or speak to the village office."
    end
  end
end
