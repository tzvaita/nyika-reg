module Resident
  # "4. My applications" — what the household has asked for and where it has got to.
  #
  # Shows status and what is outstanding, never an eligibility judgement. The
  # platform supports applications and records outcomes; the programme office
  # decides, and a household must not read a status here as a decision.
  class ApplicationsController < ApplicationController
    include ResidentAccess

    def index
      @cases = @household.programme_cases.order(opened_on: :desc)
    end
  end
end
