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

  # Lets a form present consent as one checkbox per purpose while keeping the
  # underlying model one row per purpose. Ticking creates a consent record;
  # UNTICKING withdraws the existing one rather than deleting it, so the fact that
  # consent was once given, and later withdrawn, stays in the record.
  attr_writer :consent_purposes
  attr_accessor :consent_channel

  after_save :apply_consent_selections

  def consent_purposes
    @consent_purposes || consent_records.active.map(&:purpose)
  end

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

  # Reconciles the ticked purposes against what is already on record. Runs only
  # when a form actually supplied a selection — an untouched person keeps their
  # existing consent untouched.
  def apply_consent_selections
    return if @consent_purposes.nil?

    selected = Array(@consent_purposes).reject(&:blank?).map(&:to_s)
    channel  = consent_channel.presence || "in_person"

    selected.each do |purpose|
      next if consented_to?(purpose)

      consent_records.create!(
        purpose: purpose,
        consent_version: ConsentRecord::CURRENT_VERSION,
        channel: channel,
        granted_on: Date.current,
        change_reason: "Consent given for #{purpose.humanize.downcase}",
        audit_source_channel: audit_source_channel
      )
    end

    # Anything no longer ticked is WITHDRAWN, never deleted.
    consent_records.active.reject { |record| selected.include?(record.purpose) }.each do |record|
      record.audit_source_channel = audit_source_channel
      record.withdraw!(reason: "Consent withdrawn for #{record.purpose.humanize.downcase}")
    end

    @consent_purposes = nil
  end
end
