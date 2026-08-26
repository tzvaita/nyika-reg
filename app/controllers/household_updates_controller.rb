# "1. Update my household" — the first item on the brief's resident menu, and the
# home page of the resident journey.
#
# See ResidentAccess for how a household is identified without an account.
#
# A resident's change never goes live unchallenged: it returns the household to
# the verification queue. A resident can never verify their own record.
class HouseholdUpdatesController < ApplicationController
  include ResidentAccess

  def show
  end

  def update
    @household.assign_attributes(household_params)

    if @household.record_resident_update!(reason: change_reason)
      redirect_to household_update_path(token: @household.token),
                  notice: "Thank you. Your changes have been sent to the village office to confirm."
    else
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  # Residents may correct how to reach and find them. They may NOT change their
  # own status, verification, reference or token — those are the registry's.
  def household_params
    params.require(:household).permit(:principal_contact, :location_description)
  end

  def change_reason
    params[:household][:change_reason].presence || "Updated by the household"
  end
end
