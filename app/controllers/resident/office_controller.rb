module Resident
  # "6. Speak to village office" — how to reach a person.
  #
  # Deliberately not a messaging feature. Until the WhatsApp/SMS work lands there
  # is no channel to send anything on, and offering a form that quietly goes
  # nowhere would be worse than telling someone where the office is.
  class OfficeController < ApplicationController
    include ResidentAccess

    def index
    end
  end
end
