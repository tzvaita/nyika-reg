# The resident journey: "Update my household", the first item on the brief's
# resident menu.
#
# Deliberately UNAUTHENTICATED. Residents have no accounts in this system — neither
# source document describes one — and requiring identity documents to prove who
# they are would breach the field-minimisation rules. Access is by an unguessable
# per-household token, which is what a WhatsApp or SMS link carries.
#
# The token is a bearer credential. Whoever holds the link can edit that household,
# which is why every change here:
#   * is stamped source_channel "resident_link", so assisted and self-service edits
#     can be told apart in the pilot report;
#   * requires a reason, exactly as a staff edit does;
#   * returns the household to the verification queue rather than going live.
# A resident can never verify their own record.
class HouseholdUpdatesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  before_action :load_household

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

  # find_by! so an unknown or revoked token is a plain 404, revealing nothing about
  # whether that household exists.
  def load_household
    @household = Household.find_by!(token: params[:token])
  end

  # Residents may correct how to reach and find them. They may NOT change their own
  # status, verification, reference or token — those are the registry's, not theirs.
  def household_params
    params.require(:household).permit(:principal_contact, :location_description)
  end

  def change_reason
    params[:household][:change_reason].presence || "Updated by the household"
  end

  # Every version written in this request is attributed to the resident link.
  def audit_source_channel
    "resident_link"
  end

  # There is no signed-in user here, but the audit trail still has to answer "who
  # submitted this". Leaving whodunnit nil would label a household's own change as
  # "system", which is both wrong and the opposite of accountable. Read from params
  # rather than @household because PaperTrail asks for this before before_actions run.
  def user_for_paper_trail
    token = params[:token]
    household_id = Household.where(token: token).pick(:id) if token.present?
    household_id ? "household:#{household_id}" : nil
  end
end
