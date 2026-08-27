# Creating a payment reference from the public site.
#
# No money moves. The reference is what lets the village office match a payment
# that arrives to the collection it was meant for — the brief's answer to
# payments that cannot be reconciled, and the reason a contribution is recorded
# BEFORE the money is sent rather than after.
#
# Nothing here confirms anything. A reference is a pledge until the office
# verifies a receipt against the approved account.
class PaymentReferencesController < ApplicationController
  layout "public"

  rate_limit to: 10, within: 1.hour, only: :create, name: "payment_reference",
             with: -> { redirect_to payments_path,
                        alert: "Too many references created. Please speak to the village office." }

  def create
    campaign = MobilisationCampaign.live.find_by(id: params[:contribution][:mobilisation_campaign_id])

    unless campaign
      return redirect_to return_path, alert: "Please choose a fund that is open."
    end

    @contribution = campaign.contributions.build(contribution_params)
    @contribution.assign_attributes(
      contribution_kind: :money,
      change_reason: "Reference created from the public site",
      audit_source_channel: "public_site"
    )
    @contribution.attach_household_from_contact

    if @contribution.save
      render :created, status: :created
    else
      redirect_to return_path, alert: @contribution.errors.full_messages.to_sentence
    end
  end

  private

  def contribution_params
    params.require(:contribution).permit(:amount, :payment_method, :contributor_name,
                                         :contributor_contact, :purpose_note, :origin)
  end

  def diaspora?
    params[:contribution][:origin].to_s == "diaspora"
  end

  def return_path
    diaspora? ? diaspora_path : payments_path
  end

  def audit_source_channel
    "public_site"
  end
end
