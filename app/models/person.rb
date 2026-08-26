class Person < ApplicationRecord
  include Auditable

  enum :relationship, {
    head: 0, spouse: 1, child: 2, parent: 3,
    sibling: 4, other_relative: 5, non_relative: 6
  }, validate: true

  # FIELD MINIMISATION: bands, not birthdays. Wide enough to be useful for
  # programme eligibility, coarse enough not to identify anyone on its own.
  enum :age_band, {
    under_5: 0, age_5_17: 1, age_18_35: 2, age_36_59: 3, age_60_plus: 4
  }, validate: { allow_nil: true }

  enum :residency_status, {
    resident: 0,   # lives here
    seasonal: 1,   # present part of the year
    absent: 2      # a member of the household but living elsewhere
  }, validate: true

  belongs_to :household
  has_many :consent_records, dependent: :restrict_with_error

  validates :name, presence: true
  validate  :age_information_present
  validates :year_of_birth,
            numericality: {
              only_integer: true,
              greater_than: 1900,
              less_than_or_equal_to: ->(_) { Date.current.year }
            },
            allow_nil: true

  scope :active, -> { where(active: true) }

  # Soft delete — a person leaving the household must not erase their history.
  def deactivate!(reason:)
    self.change_reason = reason
    update!(active: false)
  end

  # Consent is per purpose: the most recent non-withdrawn record for that purpose.
  def consent_for(purpose)
    consent_records.where(purpose: purpose, withdrawn_at: nil).order(:granted_on).last
  end

  def consented_to?(purpose)
    consent_for(purpose).present?
  end

  def to_s
    name
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name relationship age_band year_of_birth residency_status
       contact_method active created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[household consent_records]
  end

  private

  # One of the two is required — never both mandatory, and never a full DOB.
  def age_information_present
    return if age_band.present? || year_of_birth.present?

    errors.add(:age_band, "or year of birth must be given")
  end
end
