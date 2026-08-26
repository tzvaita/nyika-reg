# Assisted capture: the same mobile-first form, driven by a signed-in registrar
# during a home visit. This is the "assisted capture" channel the brief pairs with
# the resident mobile form.
#
# Unlike the resident link this is authenticated and authorised through the same
# Ability class as the admin workspace, and it can create households and members.
# What it cannot do is verify: a registrar never confirms their own capture.
module Capture
  class HouseholdsController < ApplicationController
    before_action :authenticate_user!
    before_action :load_household, only: [ :edit, :update ]

    def new
      @household = Household.new(capture_source: :assisted_visit)
      @household.people.build
      authorize! :create, @household
    end

    def create
      @household = Household.new(household_params)
      @household.captured_by = current_user
      @household.change_reason = "Captured on an assisted visit"
      authorize! :create, @household

      if @household.save
        redirect_to edit_capture_household_path(@household),
                    notice: "Household #{@household.reference} captured. Add members, then submit it."
      else
        @household.people.build if @household.people.empty?
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! :update, @household
      @household.people.build
    end

    def update
      authorize! :update, @household

      @household.assign_attributes(household_params)
      @household.change_reason = params[:household][:change_reason].presence || "Updated on an assisted visit"

      if @household.save
        submit_if_requested
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_household
      @household = Household.find(params[:id])
    end

    # Submitting is a separate, explicit act: capture and "I am finished" are not the
    # same decision, and only the second one puts work into the verification queue.
    def submit_if_requested
      if params[:submit_for_verification].present? && @household.draft?
        authorize! :submit_for_verification, @household
        @household.submit_for_verification!(reason: "Capture complete")
        redirect_to edit_capture_household_path(@household),
                    notice: "Sent to the verification queue."
      else
        redirect_to edit_capture_household_path(@household), notice: "Saved."
      end
    end

    def household_params
      params.require(:household).permit(
        :name, :principal_contact, :location_description, :capture_source,
        people_attributes: [
          :id, :name, :relationship, :age_band, :year_of_birth,
          :residency_status, :contact_method, :active, :consent_channel,
          { consent_purposes: [] }
        ]
      )
    end

    # Every version written here is attributed to assisted capture, which is how the
    # pilot separates staff-entered records from ones households updated themselves.
    def audit_source_channel
      "assisted"
    end
  end
end
