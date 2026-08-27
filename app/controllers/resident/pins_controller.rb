module Resident
  # Choosing your own PIN, from inside a session you already hold.
  #
  # Reachable only when already signed in — with the temporary PIN the office
  # issued, or the household's own. There is no way here from a phone number.
  class PinsController < ApplicationController
    layout "public"

    include ResidentSession
    before_action :require_resident_session

    def edit
    end

    def update
      household = resident_household

      if params[:pin].to_s != params[:pin_confirmation].to_s
        return render :edit, status: :unprocessable_entity,
                             locals: { error: "The two PINs did not match." }
      end

      household.audit_source_channel = "resident_link"

      if household.update(pin: params[:pin], pin_temporary: false,
                          pin_set_at: Time.current,
                          change_reason: "PIN chosen by the household")
        redirect_to household_dashboard_path, notice: "Your PIN has been saved."
      else
        render :edit, status: :unprocessable_entity,
                      locals: { error: household.errors.full_messages.to_sentence }
      end
    end
  end
end
