class CaseDocument < ApplicationRecord
  include Auditable

  # What kind of evidence was sighted. These name the DOCUMENT, never its
  # contents: "assessment letter", not what the assessment said.
  enum :document_type, {
    proof_of_enrolment: 0,
    birth_certificate_sighted: 1,
    household_confirmation: 2,
    assessment_letter: 3,
    payment_reference: 4,
    other_evidence: 5
  }, validate: true

  enum :verification_status, {
    recorded: 0,   # someone says it exists
    verified: 1,   # a second person has sighted it
    rejected: 2    # sighted and not accepted
  }, validate: true

  belongs_to :documentable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User", optional: true
  belongs_to :verified_by, class_name: "User", optional: true

  validates :sighted_on, presence: true

  # The verification_status enum already provides .recorded, .verified and
  # .rejected scopes — no need to restate them.

  before_validation :set_sighted_on, on: :create

  # Verification is a second pair of eyes here too: whoever recorded a document
  # is not the one who confirms it.
  def verify!(by:, reason: nil)
    raise ArgumentError, "the person who recorded a document cannot verify it" if uploaded_by_id == by&.id

    self.change_reason = reason || "Evidence verified"
    update!(verification_status: :verified, verified_by: by, verified_at: Time.current)
  end

  def reject!(by:, reason:)
    self.change_reason = reason
    update!(verification_status: :rejected, verified_by: by, verified_at: Time.current)
  end

  def to_s
    document_type.humanize
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id document_type verification_status sighted_on verified_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[documentable uploaded_by verified_by]
  end

  private

  def set_sighted_on
    self.sighted_on ||= Date.current
  end
end
