module Resident
  # "2. Government support" — a household asks to be considered for a programme.
  #
  # This is the deck's stage 1 (identify) and stage 2 (consent) happening
  # together, which is the honest order: a household cannot meaningfully be asked
  # to consent to a case that does not exist, and a case must not exist without
  # their agreement. So the request form CAPTURES CONSENT EXPLICITLY, creating a
  # purpose-specific consent record rather than assuming that asking implies
  # agreeing.
  #
  # What this does NOT do is decide anything. It opens a case for the village
  # office to work, exactly as a walk-in request would.
  class SupportController < ApplicationController
    include ResidentAccess

    def index
      @programme_types = ProgrammeCase.programme_types.keys
      @members = @household.active_people
    end

    def create
      programme_type = params[:programme_type]
      beneficiary = @household.active_people.find_by(id: params[:beneficiary_id])

      unless ProgrammeCase.programme_types.key?(programme_type)
        return redirect_to resident_support_path(token: token),
                           alert: "Please choose which kind of support you are asking about."
      end

      # Consent is not implied by asking. It has to be given.
      unless params[:consent_given] == "1"
        return redirect_to resident_support_path(token: token),
                           alert: "We can only open a request if you agree to be considered for programmes."
      end

      ActiveRecord::Base.transaction do
        record_programme_consent(beneficiary)
        @programme_case = build_case(programme_type, beneficiary)
        @programme_case.refresh_stage!(reason: "Opened from the household's own request")
      end

      redirect_to resident_applications_path(token: token),
                  notice: "Your request has been sent to the village office. They will be in touch."
    end

    private

    def build_case(programme_type, beneficiary)
      ProgrammeCase.create!(
        household: @household,
        beneficiary: beneficiary,
        programme_type: programme_type,
        change_reason: "Requested by the household",
        audit_source_channel: "resident_link"
      )
    end

    # Consent recorded against the people the case is actually for, at the
    # current wording version, through the channel it was given on.
    def record_programme_consent(beneficiary)
      people = beneficiary ? [ beneficiary ] : @household.active_people

      people.each do |person|
        next if person.consented_to?(:programme)

        person.consent_records.create!(
          purpose: :programme,
          consent_version: ConsentRecord::CURRENT_VERSION,
          channel: :whatsapp,
          granted_on: Date.current,
          change_reason: "Agreed when asking to be considered for support",
          audit_source_channel: "resident_link"
        )
      end
    end
  end
end
