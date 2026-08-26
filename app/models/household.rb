class Household < ApplicationRecord
  include Auditable

  # Enum ordinals are persisted as integers: append only, never reorder.
  enum :status, {
    draft: 0,      # being captured, not yet submitted
    pending: 1,    # submitted, awaiting verification
    verified: 2,   # confirmed by an administrator
    inactive: 3    # no longer active. This is the soft-delete terminus.
  }, validate: true

  enum :capture_source, {
    assisted_visit: 0,   # registrar visited the homestead
    community_event: 1,  # captured at a gathering
    self_reported: 2     # household came forward
  }, validate: true

  belongs_to :captured_by, class_name: "User", optional: true
  belongs_to :verified_by, class_name: "User", optional: true

  has_many :people, dependent: :restrict_with_error
  has_many :consent_records, through: :people

  validates :name, presence: true
  validates :reference, presence: true, uniqueness: true

  before_validation :assign_reference, on: :create

  # The two dashboard queues from the brief.
  scope :capture_queue,      -> { where(status: :draft).order(updated_at: :asc) }
  scope :verification_queue, -> { where(status: :pending).order(updated_at: :asc) }
  scope :live,               -> { where.not(status: :inactive) }

  # Only pending households can be verified, and only by a user allowed to do it.
  # Authorisation itself lives in Ability; this guards the state machine.
  def verify!(by:, reason: nil)
    raise ArgumentError, "only a pending household can be verified" unless pending?

    self.change_reason = reason || "Marked verified"
    update!(status: :verified, verified_by: by, verified_at: Time.current,
            last_confirmed_on: Date.current)
  end

  def submit_for_verification!(reason: nil)
    raise ArgumentError, "only a draft household can be submitted" unless draft?

    self.change_reason = reason || "Submitted for verification"
    update!(status: :pending)
  end

  # Soft delete. Nothing in the registry is ever destroyed.
  def deactivate!(reason:)
    self.change_reason = reason
    update!(status: :inactive)
  end

  def active_people
    people.where(active: true)
  end

  # Fields the data-quality report treats as required (plan step 7).
  REQUIRED_FOR_COMPLETENESS = %w[name principal_contact location_description].freeze

  def missing_required_fields
    REQUIRED_FOR_COMPLETENESS.reject { |f| public_send(f).present? }
  end

  def complete?
    missing_required_fields.empty? && active_people.any?
  end

  def to_s
    "#{reference} — #{name}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference name principal_contact location_description
       capture_source status last_confirmed_on verified_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[people consent_records captured_by verified_by]
  end

  private

  # Human-readable and safe to say out loud: NYK-2026-0001.
  def assign_reference
    return if reference.present?

    year = Date.current.year
    last = Household.where("reference LIKE ?", "NYK-#{year}-%").order(:reference).last
    seq  = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("NYK-%d-%04d", year, seq)
  end
end
