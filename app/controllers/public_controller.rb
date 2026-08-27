# The public website. No login, no token, no personal data.
#
# WHAT IS PUBLIC: what the platform does, the trust rules, and each campaign's
# name, purpose, target, amount raised and the approved account to pay into.
#
# WHAT IS NEVER PUBLIC: any household or person name, reference, location or
# contact; anything at all about programme cases; and specifically WHO
# CONTRIBUTED AND WHO DID NOT. Publishing contributor lists is a real village
# practice and it turns the register into an instrument of social pressure.
# test/integration/public_site_test.rb enforces this rather than trusting these
# templates to stay honest.
class PublicController < ApplicationController
  layout "public"

  def home
    @open_campaigns = MobilisationCampaign.live.order(:opens_on).limit(3)
  end

  def about
  end

  def privacy
  end

  def contact
  end

  def services
  end

  def payments
    @open_campaigns = MobilisationCampaign.live.order(:opens_on)
    @closed_campaigns = MobilisationCampaign.where(status: :closed).order(closes_on: :desc).limit(5)
    @routes = Contribution::LOCAL_METHODS
    @contribution = Contribution.new(origin: :local)
  end

  def diaspora
    @open_campaigns = MobilisationCampaign.live.order(:opens_on)
    @routes = Contribution::DIASPORA_METHODS
    @contribution = Contribution.new(origin: :diaspora)
  end
end
