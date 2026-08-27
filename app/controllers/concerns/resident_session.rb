# Who the resident is, once they are signed in.
#
# Separate from ResidentAccess because the sign-in and PIN-change screens need to
# know about the session without trying to load a household from a URL — they are
# the pages you reach when you do not have one yet.
module ResidentSession
  extend ActiveSupport::Concern

  # A signed-in session should not stay open all day on a handset someone else
  # may pick up.
  RESIDENT_SESSION_TIMEOUT = 30.minutes

  included do
    skip_before_action :authenticate_user!, raise: false
    helper_method :resident_household, :resident_signed_in?
  end

  private

  def resident_household
    return @resident_household if defined?(@resident_household)

    @resident_household =
      if session[:resident_household_id].blank?
        nil
      elsif resident_session_expired?
        reset_resident_session
        nil
      else
        Household.find_by(id: session[:resident_household_id])
      end
  end

  def resident_signed_in?
    resident_household.present?
  end

  def start_resident_session(household)
    session[:resident_household_id] = household.id
    session[:resident_signed_in_at] = Time.current.to_i
    @resident_household = household
  end

  def reset_resident_session
    session.delete(:resident_household_id)
    session.delete(:resident_signed_in_at)
    @resident_household = nil
  end

  def resident_session_expired?
    signed_in_at = session[:resident_signed_in_at]
    signed_in_at.blank? || Time.at(signed_in_at.to_i) < RESIDENT_SESSION_TIMEOUT.ago
  end

  def require_resident_session
    return if resident_household

    redirect_to registry_path, alert: "Please sign in to open your household."
  end

  def audit_source_channel
    "resident_link"
  end

  def user_for_paper_trail
    household_id = session[:resident_household_id]
    household_id ||= Household.where(token: params[:token]).pick(:id) if params[:token].present?
    household_id ? "household:#{household_id}" : nil
  end
end
