module Resident
  # "5. My receipts" — proof of what this household has given.
  #
  # Only VERIFIED receipts are shown as confirmed. Anything still being checked
  # is shown as such rather than being hidden: a household is entitled to see
  # that their payment is known about but not yet confirmed.
  class ReceiptsController < ApplicationController
    include ResidentAccess

    def index
      @contributions = @household.contributions.includes(:receipts, :mobilisation_campaign)
                                 .order(created_at: :desc)
    end
  end
end
