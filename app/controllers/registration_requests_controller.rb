# "Ask to be registered" — the one place the public can write to.
#
# It creates an inert REQUEST, never a household, a person or a consent record.
# A registrar visits or calls, explains what registration means, takes consent
# properly, and only then captures a record. A stranger on the internet cannot
# put anything into the register.
class RegistrationRequestsController < ApplicationController
  layout "public"

  # A speed bump, not protection: Rails.cache is per-process memory here, so this
  # slows a casual flood rather than stopping a determined one. Real moderation
  # happens in the queue, which is why requests do nothing until actioned.
  rate_limit to: 5, within: 1.hour, only: :create,
             with: -> { redirect_to new_registration_request_path,
                        alert: "Thank you — we already have your request. Please speak to the village office." }

  def new
    @registration_request = RegistrationRequest.new
  end

  def create
    # Honeypot: a field no person sees and no person fills. Silently succeed so a
    # bot learns nothing from the response.
    return render :created if params[:website].present?

    @registration_request = RegistrationRequest.new(registration_request_params)
    @registration_request.change_reason = "Requested from the public website"
    @registration_request.audit_source_channel = "public_site"

    if @registration_request.save
      render :created, status: :created
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Only what is needed to find someone and call them. No ages, no household
  # composition, no identity numbers — none of that is ours to hold until they
  # are registered and have agreed to it.
  def registration_request_params
    params.require(:registration_request).permit(:name, :contact_method, :location_hint, :note)
  end

  def audit_source_channel
    "public_site"
  end
end
