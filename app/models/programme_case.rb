class ProgrammeCase < ApplicationRecord
  include Auditable

  # The five stages from the concept deck: identify -> consent -> evidence ->
  # submit -> outcome. Ordinals are persisted integers: append only.
  enum :status, {
    identified: 0,        # a need was noticed, or the household asked
    awaiting_consent: 1,  # cannot proceed until the beneficiary agrees
    gathering_evidence: 2,
    ready_to_submit: 3,
    submitted: 4,         # sent to the responsible programme
    closed: 5             # an outcome was recorded
  }, validate: true

  enum :programme_type, {
    beam: 0,                # school fees assistance
    drought_relief: 1,
    disability_support: 2,  # the assistance, not any detail about a person
    other_support: 3
  }, validate: true

  # The platform records outcomes; it does not make them. Government keeps its
  # decision authority — the deck is explicit about this.
  enum :outcome, {
    approved: 0,
    rejected: 1,
    pending_with_programme: 2,
    benefit_received: 3
  }, validate: { allow_nil: true }

  belongs_to :household
  belongs_to :beneficiary, class_name: "Person", optional: true
  belongs_to :opened_by, class_name: "User", optional: true
  belongs_to :submitted_by, class_name: "User", optional: true

  has_many :case_documents, as: :documentable, dependent: :restrict_with_error

  validates :reference, presence: true, uniqueness: true
  validates :opened_on, presence: true
  validate  :beneficiary_belongs_to_household

  before_validation :assign_reference, on: :create
  before_validation :set_opened_on, on: :create

  scope :open_cases, -> { where.not(status: :closed) }
  scope :awaiting_action, -> { where(status: [ :awaiting_consent, :gathering_evidence ]) }
  scope :submission_queue, -> { where(status: :ready_to_submit) }

  # Which documents each programme needs before it can be submitted. Kept here,
  # in one place, so the checklist shown to a registrar and the check that gates
  # submission can never disagree.
  EVIDENCE_REQUIRED = {
    "beam" => %w[proof_of_enrolment birth_certificate_sighted household_confirmation],
    "drought_relief" => %w[household_confirmation],
    "disability_support" => %w[assessment_letter household_confirmation],
    "other_support" => %w[household_confirmation]
  }.freeze

  def required_document_types
    EVIDENCE_REQUIRED.fetch(programme_type, [])
  end

  def supplied_document_types
    case_documents.verified.map(&:document_type)
  end

  def missing_document_types
    required_document_types - supplied_document_types
  end

  def evidence_complete?
    missing_document_types.empty?
  end

  # A case may only proceed where the person it is for has agreed to be
  # considered for programmes. This is the consent model doing real work rather
  # than being a box that was ticked once.
  def consent_present?
    people_needing_consent.all? { |person| person.consented_to?(:programme) }
  end

  def people_needing_consent
    beneficiary ? [ beneficiary ] : household.active_people.to_a
  end

  def people_missing_consent
    people_needing_consent.reject { |person| person.consented_to?(:programme) }
  end

  # Basic eligibility only. The brief asks the system to "check basic
  # eligibility", not to decide entitlement — the answer is a prompt for a human,
  # never a refusal.
  def eligibility_notes
    notes = []

    case programme_type
    when "beam"
      unless household.active_people.any? { |p| p.age_band == "age_5_17" }
        notes << "No school-age member (5–17) is recorded in this household."
      end
    when "drought_relief"
      unless household.active_people.any? { |p| p.residency_status == "resident" }
        notes << "No member is recorded as resident in the village."
      end
    end

    notes << "The household record has not been verified yet." unless household.verified?
    notes
  end

  def likely_eligible?
    eligibility_notes.empty?
  end

  # Everything that must be true before this can go to the programme office.
  def blockers
    blocking = []
    blocking << "Consent to be considered for programmes is missing for: " \
                "#{people_missing_consent.map(&:name).to_sentence}" if people_missing_consent.any?
    blocking << "Missing evidence: #{missing_document_types.map(&:humanize).to_sentence}" unless evidence_complete?
    blocking << "The household is not verified." unless household.verified?
    blocking
  end

  def submittable?
    blockers.empty? && !submitted? && !closed?
  end

  def submit!(by:, reason: nil)
    raise ArgumentError, "case cannot be submitted: #{blockers.to_sentence}" unless submittable?

    self.change_reason = reason || "Submitted to the programme office"
    update!(status: :submitted, submitted_by: by, submitted_at: Time.current)
  end

  def record_outcome!(outcome:, note: nil, reason: nil)
    self.change_reason = reason || "Outcome recorded: #{outcome.to_s.humanize}"
    update!(status: :closed, outcome: outcome, outcome_note: note,
            outcome_recorded_at: Time.current)
  end

  # Moves the case to whichever stage its actual state justifies, so the status
  # cannot drift away from the evidence and consent on record.
  def refresh_stage!(reason: "Stage recalculated")
    return if submitted? || closed?

    next_status =
      if !consent_present? then :awaiting_consent
      elsif !evidence_complete? then :gathering_evidence
      else :ready_to_submit
      end

    return if status == next_status.to_s

    self.change_reason = reason
    update!(status: next_status)
  end

  def to_s
    "#{reference} — #{programme_type.humanize}"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference programme_type status outcome opened_on submitted_at
       outcome_recorded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[household beneficiary opened_by submitted_by case_documents]
  end

  private

  def assign_reference
    return if reference.present?

    year = Date.current.year
    last = ProgrammeCase.where("reference LIKE ?", "CASE-#{year}-%").order(:reference).last
    seq  = last ? last.reference.split("-").last.to_i + 1 : 1
    self.reference = format("CASE-%d-%04d", year, seq)
  end

  def set_opened_on
    self.opened_on ||= Date.current
  end

  def beneficiary_belongs_to_household
    return if beneficiary.blank? || household.blank?
    return if beneficiary.household_id == household_id

    errors.add(:beneficiary, "must be a member of this household")
  end
end
