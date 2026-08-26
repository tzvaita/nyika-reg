# Shared by every page a resident reaches through their household link.
#
# There is no account and no password. The household is identified solely by an
# unguessable token, and every page is scoped to THAT household — a resident can
# never see another family's record. Every change made through these pages is
# stamped source_channel "resident_link" and attributed to the household, so the
# audit trail can answer "who submitted this" without inventing a user.
module ResidentAccess
  extend ActiveSupport::Concern

  included do
    skip_before_action :authenticate_user!, raise: false

    # The token is unguessable, but the endpoint is public, so brute-forcing it
    # should at least be slow. A speed bump rather than a wall: Rails.cache is
    # per-process memory here, so this does not survive a restart or coordinate
    # across processes.
    rate_limit to: 60, within: 1.minute,
               with: -> { head :too_many_requests }

    before_action :load_household
    helper_method :resident_household
  end

  private

  # find_by! so an unknown or revoked token is a plain 404 that reveals nothing
  # about whether that household exists.
  def load_household
    @household = Household.find_by!(token: params[:token])
  end

  def resident_household
    @household
  end

  def token
    params[:token]
  end

  def audit_source_channel
    "resident_link"
  end

  # Read from params rather than @household: PaperTrail asks for this before
  # before_actions have run.
  def user_for_paper_trail
    household_id = Household.where(token: params[:token]).pick(:id) if params[:token].present?
    household_id ? "household:#{household_id}" : nil
  end
end
