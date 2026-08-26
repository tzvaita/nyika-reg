module Resident
  # "3. Make a payment" — pledge to an open campaign.
  #
  # No money moves here. The household records what they intend to give, and the
  # page shows them THE APPROVED RECEIVING ACCOUNT so they pay the right place —
  # the brief's mitigation for residents paying the wrong account, surfaced to
  # the person who actually needs it.
  #
  # A pledge is created as `pledged`. It becomes reconciled only when the village
  # office verifies a receipt. A resident cannot mark their own payment received.
  class PaymentsController < ApplicationController
    include ResidentAccess

    def index
      @campaigns = MobilisationCampaign.live.order(:opens_on)
      @contributions = @household.contributions.order(created_at: :desc)
    end

    def create
      campaign = MobilisationCampaign.live.find_by(id: params[:mobilisation_campaign_id])

      unless campaign
        return redirect_to resident_payments_path(token: token),
                           alert: "That campaign is not open for contributions."
      end

      contribution = @household.contributions.build(
        mobilisation_campaign: campaign,
        contribution_kind: params[:contribution_kind].presence || "money",
        amount: params[:amount].presence,
        item_description: params[:item_description].presence,
        payment_method: params[:payment_method].presence,
        change_reason: "Pledged by the household",
        audit_source_channel: "resident_link"
      )

      if contribution.save
        redirect_to resident_payments_path(token: token),
                    notice: "Thank you. Please pay to the account shown, and keep your reference."
      else
        redirect_to resident_payments_path(token: token),
                    alert: contribution.errors.full_messages.to_sentence
      end
    end
  end
end
